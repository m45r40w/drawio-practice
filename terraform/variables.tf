variable "project" {
  description = "リソース名の先頭に付ける名前"
  type        = string
  default     = "drawio-practice"
}

variable "region" {
  description = "作成先のリージョン（図の Region 枠）"
  type        = string
  default     = "ap-northeast-1"
}

variable "log_retention_days" {
  description = "CloudWatch Logs の保存日数"
  type        = number
  default     = 14
}

variable "s3_force_destroy" {
  description = "true にすると、中身が残っていても destroy で S3 バケットを削除する（練習用）"
  type        = bool
  default     = false
}
