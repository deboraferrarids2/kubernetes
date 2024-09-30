cluster_name = "eks-cluster"
cluster_role_arn = "arn:aws:iam::778862303728:role/eks-role"
node_role_arn = "arn:aws:iam::778862303728:role/aws-service-role/eks-nodegroup.amazonaws.com/AWSServiceRoleForAmazonEKSNodegroup"
desired_size = 2
max_size = 3
min_size = 1
subnet_ids = ["subnet-0b4d94ca6d5a6d09a", "subnet-02283949570cda0c1"]
instance_type = "t3.micro" 
