# 클라우드 워치 - CPU 90%이상 가동 경고
resource "aws_cloudwatch_metric_alarm" "high_cpu"{
  alarm_name = "${var.cluster_name}-high-cpu-utilization"
  namespace = "AWS?EC2"
  metric_name = "CPUUtilization"

  dimensions = {
    AutoScalingGroupName = "${var.ascg_name}"
  }

  comparison_operator = "GreaterThanThreshold"
  evaluation_periods = 1
  period = 300
  statistic = "Average"
  threshold = 90
  unit = "Percent"
}

resource "aws_cloudwatch_metric_alarm" "low_cpu"{
  count = format("%.1s", var.instance_type) == "t" ? 1 : 0
  
  alarm_name = "${var.cluster_name}-low-cpu-credit-balance"
  namespace = "AWS?EC2"
  metric_name = "CPUCreditBalance"

  dimensions = {
    AutoScalingGroupName = "${var.ascg_name}"
  }

  comparison_operator = "LessThanThreshold"
  evaluation_periods = 1
  period = 300
  statistic = "Minimum"
  threshold = 10
  unit = "Count"
}