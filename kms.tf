variable "kms_description" {
  description = "(Required) The description of the key as viewed in AWS console."
}

variable "kms_key_usage" {
  description = "(Optional) Specifies the intended use of the key. Defaults to ENCRYPT/DECRYPT, and only symmetric encryption and decryption are supported."
  default = "ENCRYPT_DECRYPT"
}

variable "kms_enable_key_rotation" {
  description = "(Optional) Specifies whether key rotation is enabled. Defaults to true."
  default = true
}

variable "kms_alias_template" {
  description = "(Optional) Template used to format the alias name of the key."
  default = "kms-%s-%s-encryptionkey-%s"
}

resource "aws_kms_key" "kms_key" {
  description = "${var.kms_description}"
  key_usage = "${var.kms_key_usage}"
  enable_key_rotation = "${var.kms_enable_key_rotation}"

  # Add a map of standards tags for this resource to a map of tags passed into the module:
  tags = "${merge(map(
    "Name", "${format(var.kms_alias_template, var.service, var.environment)}"),
    local.all_tags
  )}"
}

resource "aws_kms_alias" "kms_alias" {
  name = "alias/${format(var.kms_alias_template, var.service, var.environment)}"
  target_key_id = "${aws_kms_key.kms_key.key_id}"
}

