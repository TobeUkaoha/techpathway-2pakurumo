# All outputs are defined in their respective .tf files.
# This file contains additional composite/summary outputs.

output "deployment_summary" {
  description = "Full deployment summary"
  value = {
    frontend_url     = "http://${aws_lb.main.dns_name}"
    backend_api_url  = "http://${aws_lb.main.dns_name}/api"
    ecs_cluster      = aws_ecs_cluster.main.name
    frontend_ecr     = aws_ecr_repository.frontend.repository_url
    backend_ecr      = aws_ecr_repository.backend.repository_url
    aws_account_id   = data.aws_caller_identity.current.account_id
    aws_region       = data.aws_region.current.name
  }
}
