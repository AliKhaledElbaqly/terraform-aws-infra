[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
![HCL](https://img.shields.io/badge/language-HCL-blue.svg)

# AWS Infrastructure with Terraform
<hr style="margin-top: -20px; margin-bottom: -12px;">

## Infrastructure, including:

- VPC with public and private subnets
- Internet Gateway and NAT Gateway for internet access
- EC2 instances (with auto scaling and ALB) (High availability & Scalability)
- Application Load Balancer (ALB)
- RDS MySQL Database
- Security Groups (Firewalls)
- Key Pair for SSH Access

![Infrastructure Diagram](https://res.cloudinary.com/dmt3wghiv/image/upload/v1754553797/Infrastructure_Diagram_meuzh9.jpg)

<hr style="margin-top: 30px; margin-bottom: -12px;">

##  Project Structure

```bash
.
├── main.tf        # Main infrastructure file
├── variables.tf   # Variables definition
├── outputs.tf     # Output values 
├── terraform.tfvars # Variable values
├── README.md      # Project documentation
├── .gitignore     # statefiles & secrets
```
<hr style="margin-top: 30px; margin-bottom: -12px;">
<h2 style="margin-bottom: 0;">Resources Created</h2>
<hr style="margin-top: 4px; margin-bottom: 12px;">



##### 1. **VPC**
Creates a custom VPC with the CIDR block defined by `var.vpc_cidr`.

##### 2. **Subnets**
- **Public Subnets**: Used for internet-facing resources (e.g., ALB).
- **Private Subnets**: For internal resources like EC2 instances and RDS.

##### 3. **Internet Gateway (IGW)**
Provides internet access to public subnets.

##### 4. **Elastic IP (EIP) + NAT Gateway**
Allows private instances to initiate outbound traffic (e.g., for package updates).

##### 5. **Route Tables**
- Public subnets route to the Internet Gateway.
- Private subnets route through the NAT Gateway.
- Subnets are explicitly associated with their respective route tables.

##### 6. **Security Groups**
- **webSG**: Allows inbound access (e.g., HTTP) to EC2 instances.
- **ALBSG**: Allows HTTP access to the Load Balancer.
- **db_sg**: Allows MySQL traffic (port 3306) only from EC2 security group.

##### 7. **Key Pair**
Creates an EC2 key pair using a local public SSH key at `~/.ssh/authkey.pub`. 
 - Note that you have to generate your own key 
 > ssh-keygen

##### 8. **EC2 Instances**
- Two EC2 instances launched in **private subnets**.
- Apache is installed and a basic HTML page is served.
- Access to these instances is through the Load Balancer only.

##### 9. **Application Load Balancer (ALB)**
- Deployed in public subnets.
- Routes HTTP traffic to EC2 instances via a Target Group.
- Uses `ALBSG` for security.

##### 10. **Auto Scaling Group (ASG)**
- Auto scales EC2 instances between 1–3 instances.
- Launch Template defines base config.
- Registered to the ALB target group.

##### 11. **RDS MySQL Instance**
- MySQL 8.0 engine deployed in **private subnets**.
- Secured using `db_sg`.
- Not publicly accessible.
- Uses a custom DB subnet group.

---

####  Modules / Structure

- `aws_vpc`, `aws_subnet`, `aws_internet_gateway`, etc.
- `for_each` for scalable subnet creation.
- `dynamic` blocks for flexible security group rules.

---

#### Configure variables

- Edit the `variables.tf` file or define values via CLI.

---

#### Initialize Terraform
```
terraform init
```

#### Preview the changes
```
terraform plan
```
#### Apply the infrastructure
```
terraform apply
```
#### Graph the infrastructure
```
terraform graph -type=plan | dot -Tpng >graph.png
```
#### Cleanup
```
terraform destroy
```
#### Security Tips

```
     terraform.tfstate & backup or variables.tf  with secrets.
     Use .gitignore to exclude them :

        .terraform/

        *.tfstate

        *.tfvars
```
## Created By

> From Scratch by  [@AliKhaled](https://github.com/AliKhaledElbaqly)


