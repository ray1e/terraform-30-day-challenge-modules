variable "server_port" {
    description = "The port the server will use for HTTP request"
    type = number
    default = 80
}

variable "instance_type" {
    description = "EC2 instance type"
    type = string
    default = "t2.micro"
}

variable "cluster_name" {
  description = "The name to use for all the clusters in the resources"
  type = string
}

variable "db_remote_state_bucket" {
  description = "The name of the s3 bucket for the database's remote state"
  type = string
}

variable "db_remote_state_key" {
  description = "The path for the databases remote state in s3"
  type = string
}

variable "min_size" {
  description = "minimum number of EC2 instances in the ASG"
  type = number
}

variable "max_size" {
  description = "The maximum size of EC2 instances in  the ASG"
}

