# -------------------------
# Namespace and Service Account
# -------------------------
resource "kubernetes_namespace" "karpenter" {
  metadata {
    name = "karpenter"
  }

  depends_on = [module.eks]
}

resource "aws_iam_role" "karpenter_controller" {
  name = "karpenter-controller-role"

  assume_role_policy = data.aws_iam_policy_document.karpenter_assume_role.json
}

data "aws_iam_policy_document" "karpenter_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn] # OIDC provider from EKS module
    }

    actions = ["sts:AssumeRoleWithWebIdentity"]

    condition {
      test     = "StringEquals"
      variable = "${module.eks.oidc_provider}:sub"
      values   = ["system:serviceaccount:karpenter:karpenter"]
    }
  }
}

resource "kubernetes_service_account" "karpenter_sa" {
  metadata {
    name      = "karpenter"
    namespace = kubernetes_namespace.karpenter.metadata[0].name
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.karpenter_controller.arn
    }
  }

  depends_on = [kubernetes_namespace.karpenter]
}

# -------------------------
# IAM Policies for Karpenter Controller
# -------------------------

# Custom policy (instead of AmazonEC2FullAccess)
resource "aws_iam_policy" "karpenter_controller_custom" {
  name        = "KarpenterControllerPolicy"
  description = "Custom permissions required for Karpenter controller"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "ec2:CreateLaunchTemplate",
          "ec2:CreateFleet",
          "ec2:RunInstances",
          "ec2:TerminateInstances",
          "ec2:DescribeInstances",
          "ec2:DescribeLaunchTemplates",
          "ec2:DescribeImages",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeAvailabilityZones",
          "ec2:DeleteLaunchTemplate",
          "ec2:CreateTags",
          "ec2:DescribeInstanceTypeOfferings",
          "eks:DescribeCluster",
          "ssm:GetParameter",
          "tag:GetResources",
          "tag:TagResources",
          "iam:CreateInstanceProfile",
          "iam:AddRoleToInstanceProfile",
          "iam:RemoveRoleFromInstanceProfile",
          "iam:DeleteInstanceProfile",
          "iam:PassRole"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "karpenter_controller_custom_attach" {
  role       = aws_iam_role.karpenter_controller.name
  policy_arn = aws_iam_policy.karpenter_controller_custom.arn
}

resource "aws_iam_role_policy_attachment" "karpenter_controller_ssm_managed" {
  role       = aws_iam_role.karpenter_controller.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "karpenter_controller_eks_cluster" {
  role       = aws_iam_role.karpenter_controller.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# -------------------------
# Node Instance Profile + Role
# -------------------------
resource "aws_iam_role" "karpenter_node_role" {
  name = "KarpenterNodeRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_instance_profile" "karpenter_node_instance_profile" {
  name = "KarpenterNodeInstanceProfile"
  role = aws_iam_role.karpenter_node_role.name
}

resource "aws_iam_role_policy_attachment" "karpenter_node_AmazonEKSWorkerNodePolicy" {
  role       = aws_iam_role.karpenter_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "karpenter_node_AmazonEKS_CNI_Policy" {
  role       = aws_iam_role.karpenter_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "karpenter_node_AmazonEC2ContainerRegistryReadOnly" {
  role       = aws_iam_role.karpenter_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# -------------------------
# Install Karpenter via Helm
# -------------------------
resource "helm_release" "karpenter" {
  name       = "karpenter"
  chart      = "karpenter"
  version    = "1.7.1" # pin to tested version
  repository = "oci://public.ecr.aws/karpenter"
  namespace  = kubernetes_namespace.karpenter.metadata[0].name

  values = [
    yamlencode({
      serviceAccount = {
        create = false
        name   = kubernetes_service_account.karpenter_sa.metadata[0].name
      }
      settings = {
        
          clusterName            = module.eks.cluster_name
          defaultInstanceProfile = aws_iam_instance_profile.karpenter_node_instance_profile.name
        
      }
    })
  ]

  depends_on = [
    kubernetes_service_account.karpenter_sa,
    aws_iam_role.karpenter_controller,
    aws_iam_instance_profile.karpenter_node_instance_profile
  ]
}

# -------------------------
# Karpenter Provisioners for x86 and arm64
# -------------------------
resource "kubernetes_manifest" "karpenter_provisioner_x86" {
  manifest = {
    apiVersion = "karpenter.sh/v1alpha5"
    kind       = "Provisioner"
    metadata = {
      name = "x86-provisioner"
    }
    spec = {
      provider = {
        instanceProfile = aws_iam_instance_profile.karpenter_node_instance_profile.name
      }
      requirements = [
        {
          key      = "kubernetes.io/arch"
          operator = "In"
          values   = ["amd64"]
        }
      ]
      limits = {
        resources = {
          cpu = "1000"
        }
      }
      ttlSecondsAfterEmpty = 30
    }
  }

  depends_on = [helm_release.karpenter]
}

resource "kubernetes_manifest" "karpenter_provisioner_arm64" {
  manifest = {
    apiVersion = "karpenter.sh/v1alpha5"
    kind       = "Provisioner"
    metadata = {
      name = "arm64-provisioner"
    }
    spec = {
      provider = {
        instanceProfile = aws_iam_instance_profile.karpenter_node_instance_profile.name
      }
      requirements = [
        {
          key      = "kubernetes.io/arch"
          operator = "In"
          values   = ["arm64"]
        }
      ]
      limits = {
        resources = {
          cpu = "1000"
        }
      }
      ttlSecondsAfterEmpty = 30
    }
  }

  depends_on = [helm_release.karpenter]
}
