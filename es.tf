variable "es_subnet_ids" {
  type = "list",
  default = [""]
}

data "aws_subnet" "es_subnets" {
  count = "${length(var.es_azs)}"

  filter {
    name = "tag:Name"
    values = ["sn-${var.subnets_name}-${var.subnet_env}-${element(var.es_azs, count.index)}"]
  }
}

# Mandatory resource for ES to be able to create network interfaces in VPC.
# (can be created beforehand through console or cli)
 resource "aws_iam_service_linked_role" "es_linked_role" {
   aws_service_name = "es.amazonaws.com"
   description = "Allows Amazon ES to manage AWS resources for a domain on your behalf."
 }

resource "aws_security_group" "es_sg" {
  name        = "sges-${var.service}-${var.environment}"
  description = "${var.service}-${var.environment} security group"
  vpc_id      = "${data.aws_vpc.current.id}"

  # Add a map of standards tags for this resource to a map of tags passed into the module:
  tags = "${merge(map(
    "Name", "sges-${var.service}-${var.environment}"),
    local.all_tags
  )}"
}

resource "aws_security_group_rule" "es_egress_all" {
  type              = "egress"
  protocol          = -1
  from_port         = 0
  to_port           = 0
  cidr_blocks       = [ "0.0.0.0/0" ]
  security_group_id = "${aws_security_group.es_sg.id}"
}

# this allows network access to the ES cluster to all subnets AZ's specified in var.es_azs
resource "aws_security_group_rule" "es_ingress" {
  count             = "${length(data.aws_subnet.es_subnets.*.cidr_block)}"
  type              = "ingress"
  protocol          = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_blocks       = [ "${element(data.aws_subnet.es_subnets.*.cidr_block, count.index)}" ]
  security_group_id = "${aws_security_group.es_sg.id}"
}

resource "random_shuffle" "es_subnet_ids" {
  input = ["${data.aws_subnet.es_subnets.*.id}"]
  result_count = "${var.es_subnet_ids[0] == "" && !var.es_multi_az ? 1 : 2}"
}

resource "aws_elasticsearch_domain" "es_domain" {
  # domain_name           = "${var.service}-${var.environment}"
  domain_name           = "${var.service}-${var.role}" # To be changed back to environment (see below)
  # Error: aws_elasticsearch_domain.es_domain: invalid value for domain_name (must start with a lowercase alphabet and be at least 3 and no more than 28 characters long. Valid characters are a-z (lowercase letters), 0-9, and - (hyphen).)
  # domain_name           = "${var.environment}"
  elasticsearch_version = "${var.es_version}"  
  # depends_on = ["aws_iam_service_linked_role.es_linked_role"]

  cluster_config {
    instance_type = "${var.es_instance_type}"
    instance_count = "${var.es_instance_count}"
    zone_awareness_enabled = "${var.es_multi_az}"
  }

  ebs_options {
    ebs_enabled = true
    volume_type = "${var.es_volume_type}"
    volume_size = "${var.es_instance_volume_size}"
  }

  vpc_options {
    security_group_ids = ["${aws_security_group.es_sg.id}"]
    subnet_ids = ["${random_shuffle.es_subnet_ids.result}"]
  }

  snapshot_options {
    automated_snapshot_start_hour = "${var.es_maintenance_start_hour}"
  }

  encrypt_at_rest {
    enabled = true,
    kms_key_id = "${aws_kms_key.kms_key.key_id}"
  }

  tags = "${merge(map(
    "Domain", "${var.service}-${var.environment}"),
    local.all_tags
  )}"
}


resource "aws_elasticsearch_domain_policy" "es_domain_policy" {
  domain_name = "${aws_elasticsearch_domain.es_domain.domain_name}"

  access_policies = <<POLICIES
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Principal": {
              "AWS": "*"
            },
            "Effect": "Allow",
            "Action": "es:*",
            "Resource": "${aws_elasticsearch_domain.es_domain.arn}/*"
        }
    ]
}
POLICIES
}

# Consul addresses for consistent naming to access service from the instance
resource "consul_node" "es_consul_node" {
  name    = "${var.service}-${var.environment}"
  address = "${aws_elasticsearch_domain.es_domain.endpoint}"
  depends_on = ["aws_elasticsearch_domain.es_domain"]
}

resource "consul_service" "es_consul_service" {
  name    = "${var.service}-${var.environment}"
  node    = "${var.service}-${var.environment}"
  depends_on = ["consul_node.es_consul_node"]
