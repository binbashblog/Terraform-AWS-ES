variable "es_azs" {
  description = "(Optional) The availability zones the EC2 instances should be launched in."
  type = "list"
  default = [ "1a", "1b", "1c"]
}
variable "es_maintenance_start_hour" {}

variable "es_version" {}
variable "es_volume_type" {}
variable "es_instance_volume_size" {}
variable "es_instance_count" {}
variable "es_instance_type" {}
variable "es_multi_az" {}

variable "subnets_name" {
  description = "(Optional) The name of the subnets to launch the instances in."
}

variable "subnet_env" {
  description = "The name of the data subnets created for Example instances."
  default = "Example-1-2-3-4-5"

