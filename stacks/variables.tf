variable name {}
variable region {
  default = "eu-west-1"
}

variable cidr_block {
  default = "10.0.0.0/16"
}

variable intra_subnets {
  type = list
  default = ["10.0.1.0/24"]
}

variable public_subnets {
  type = list
  default = ["10.0.101.0/24"]
}

variable zones {
  type = list
  default = ["eu-west-1a"]
}

variable cpu {
  default = "256"
}
variable memory {
  default = "1024"
}

variable registry {}
variable image {}
variable tag {
  default = "latest"
}
variable environment_variables {
  type = list(object({
    name = string
    value = string
  }))
  default = []
}

variable log_retention_in_days {
  default = "30"
}

variable bucket {}

variable account_id {}

variable tags { default = {} }

