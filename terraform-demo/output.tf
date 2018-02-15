output "elb-dns" {
  value = "${aws_elb.ansible-load-balancer.dns_name}"
}
