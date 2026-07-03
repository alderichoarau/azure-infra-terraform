variable "owner" {
  description = "Learner identifier, used to build unique resource names and tags"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the Resource Group to deploy into"
  type        = string
}

variable "location" {
  description = "Azure region for the Function App and its dedicated storage account"
  type        = string
}

variable "service_plan_id" {
  description = "ID of the shared App Service Plan the Function App runs on"
  type        = string
}

variable "tags" {
  description = "Tags applied to all resources in this module"
  type        = map(string)
}
