#!/usr/bin/env python3
"""
Generate architecture diagram for terraform-aws-website-pod module.

This diagram is generated from analysis of the actual Terraform code.

Requirements:
    pip install diagrams

Usage:
    python architecture.py

Output:
    architecture.png (in current directory)
"""
from textwrap import dedent

from diagrams import Diagram, Cluster, Edge
from diagrams.aws.compute import EC2, AutoScaling
from diagrams.aws.network import ELB, Route53
from diagrams.aws.security import ACM, IAM
from diagrams.aws.storage import S3
from diagrams.aws.management import Cloudwatch
from diagrams.aws.integration import SNS
from diagrams.onprem.client import Users

fontsize = "16"

# Match MkDocs Material theme fonts (Roboto)
# Increase sizes for better readability
graph_attr = {
    "splines": "spline",
    "nodesep": "1.0",
    "ranksep": "1.0",
    "fontsize": fontsize,
    "fontname": "Roboto",
    "dpi": "200",
    "compound": "true",
}

node_attr = {
    "fontname": "Roboto",
    "fontsize": fontsize,
}

edge_attr = {
    "fontname": "Roboto",
    "fontsize": fontsize,
}

with Diagram(
    "Website Pod - AWS Architecture",
    filename="architecture",
    show=False,
    direction="TB",
    graph_attr=graph_attr,
    node_attr=node_attr,
    edge_attr=edge_attr,
    outformat="png",
):
    # External - Users
    users = Users("\nUsers")

    with Cluster("AWS Account"):

        # Use side-by-side layout with Monitoring on left, VPC on right
        with Cluster("Monitoring", graph_attr={"rank": "same"}):
            sns = SNS("\nSNS Topic")
            alarm_cpu = Cloudwatch("\nCPU")
            alarm_health = Cloudwatch("\nUnhealthy")
            alarm_latency = Cloudwatch("\nLatency")

        with Cluster("VPC"):

            # Public Subnets - ALB
            with Cluster("Public Subnets"):
                alb = ELB("\nALB\n(HTTPS:443)")

            # Private Subnets - ASG and EC2
            with Cluster("Private Subnets"):
                asg = AutoScaling("\nASG")
                instances = [
                    EC2("\nEC2"),
                    EC2("\nEC2"),
                ]
                # IAM
                iam = IAM("\nIAM")



        # Access Logs
        s3_logs = S3("\nS3 Logs")

        # DNS and Certificate
        with Cluster("DNS & SSL"):
            route53 = Route53("\nRoute53")
            acm = ACM("\nACM Cert")

    # ============ CONNECTIONS ============

    # User traffic flow
    users >> Edge(label="HTTPS", color="green") >> alb

    # DNS resolution
    route53 >> Edge(label="A Record", style="dashed") >> alb

    # SSL Certificate
    acm >> Edge(label="SSL Cert", style="dashed") >> alb

    # ALB to instances
    alb >> Edge(label="HTTP:80", color="blue") >> instances[0]
    alb >> Edge(label="HTTP:80", color="blue") >> instances[1]

    # ASG manages instances
    asg >> Edge(style="dotted") >> instances[0]
    asg >> Edge(style="dotted") >> instances[1]

    # ALB logs to S3
    alb >> Edge(label="Access Logs", style="dashed", color="orange") >> s3_logs

    # ALB metrics to CloudWatch
    alb >> Edge(style="dashed") >> alarm_health
    alb >> Edge(style="dashed") >> alarm_latency

    # ASG metrics to CloudWatch
    asg >> Edge(style="dashed") >> alarm_cpu

    # Alarms to SNS
    alarm_cpu >> sns
    alarm_health >> sns
    alarm_latency >> sns

    # IAM for instances
    iam >> Edge(style="dotted") >> instances[0]
