

output "autoscaling_group_name" {
  value = module.eks.self_managed_node_groups_autoscaling_group_names[0]
}