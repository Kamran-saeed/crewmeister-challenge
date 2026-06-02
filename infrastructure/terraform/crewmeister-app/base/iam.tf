data "aws_caller_identity" "current" {
  count = var.external_secrets.enabled ? 1 : 0
}

data "aws_iam_policy_document" "external_secrets" {
  count = var.external_secrets.enabled ? 1 : 0

  statement {
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
    resources = [
      "arn:aws:secretsmanager:eu-central-1:${data.aws_caller_identity.current[0].account_id}:secret:${var.external_secrets.secret_name}-*"
    ]
  }
}

resource "aws_iam_policy" "external_secrets" {
  count = var.external_secrets.enabled ? 1 : 0

  name   = "${var.release_name}-external-secrets"
  policy = data.aws_iam_policy_document.external_secrets[0].json
}

resource "aws_iam_role_policy_attachment" "external_secrets" {
  count = var.external_secrets.enabled ? 1 : 0

  role       = element(split("/", var.external_secrets.eso_role_arn), length(split("/", var.external_secrets.eso_role_arn)) - 1)
  policy_arn = aws_iam_policy.external_secrets[0].arn
}
