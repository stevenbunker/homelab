
# The aws-ebs-csi-driver addon (eks.tf) makes the ebs.csi.aws.com provisioner available, but
# doesn't create a default StorageClass. Define one so PVCs get gp3 volumes without callers
# needing to specify a storageClassName.
resource "kubernetes_storage_class_v1" "gp3" {
  metadata {
    name = "gp3"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  storage_provisioner    = "ebs.csi.aws.com"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true

  parameters = {
    type      = "gp3"
    encrypted = "true"
  }

  depends_on = [module.eks]
}
