```mermaid
flowchart LR
    subgraph AWS_Cloud["AWS Cloud"]
        ALB[Application Load Balancer]
        EKS[EKS Cluster\nx86 + ARM nodes]
        RDS[(PostgreSQL RDS)]
    end

    subgraph CI_CD["CI/CD"]
        GitHub[GitHub Actions / GitLab CI]
        Registry[ECR / Artifact Registry]
    end

    User -->|HTTPS| ALB
    ALB -->|Service Traffic| EKS
    EKS -->|DB Traffic| RDS
    GitHub --> Registry --> EKS
