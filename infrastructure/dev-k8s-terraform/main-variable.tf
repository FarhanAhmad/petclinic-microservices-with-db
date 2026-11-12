variable "mykey" {}
variable "aval_zone" {}
variable "env" {}
variable "master_instance_type" {}
variable "worker_instance_type" {}
variable "worker_count" {
  default = 2
}
variable "myami" {}
variable "master_device_size" {}
variable "worker_device_size" {}