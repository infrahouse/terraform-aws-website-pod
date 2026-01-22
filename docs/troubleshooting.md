# Troubleshooting

This guide covers common issues and their solutions when using the terraform-aws-website-pod module.

## Deployment Issues

### Certificate Validation Timeout

**Symptoms:**
- Terraform hangs at `aws_acm_certificate_validation.website`
- Error: "timeout while waiting for state to become 'ISSUED'"

**Causes:**
- DNS propagation delay
- Incorrect Route53 zone ID
- Cross-account DNS misconfiguration

**Solutions:**

1. Verify the zone ID is correct:
   ```bash
   aws route53 get-hosted-zone --id YOUR_ZONE_ID
   ```

2. Check if validation records were created:
   ```bash
   aws route53 list-resource-record-sets --hosted-zone-id YOUR_ZONE_ID | grep CNAME
   ```

3. For cross-account DNS, verify the provider configuration:
   ```hcl
   provider "aws" {
     alias = "dns"
     assume_role {
       role_arn = "arn:aws:iam::DNS_ACCOUNT:role/route53-admin"
     }
   }
   ```

4. Increase timeout (add to your configuration):
   ```hcl
   resource "aws_acm_certificate_validation" "website" {
     timeouts {
       create = "60m"
     }
   }
   ```

### Instances Not Becoming Healthy

**Symptoms:**
- Terraform hangs at `aws_autoscaling_group.website`
- Error: "timeout while waiting for state to become 'healthy'"
- Instances keep getting replaced

**Causes:**
- Health check path returns non-200 status
- Application not starting properly
- Security group blocking traffic
- Instance failing to provision

**Solutions:**

1. Check instance status in AWS Console or CLI:
   ```bash
   aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names YOUR_ASG_NAME
   ```

2. Connect to an instance and check logs:
   ```bash
   # Check cloud-init
   sudo cat /var/log/cloud-init-output.log

   # Check application logs
   sudo journalctl -u your-service
   ```

3. Test health check endpoint manually:
   ```bash
   curl -v http://localhost/index.html
   ```

4. Verify security groups allow traffic from ALB:
   ```bash
   aws ec2 describe-security-groups --group-ids YOUR_BACKEND_SG_ID
   ```

5. Temporarily increase timeouts:
   ```hcl
   module "website" {
     # ...
     health_check_grace_period   = 900   # 15 minutes
     wait_for_capacity_timeout   = "30m"
   }
   ```

### Provider Configuration Errors

**Symptoms:**
- Error: "Provider configuration not present"
- Error: "Configuration for provider 'aws.dns' is not present"

**Solution:**

Always pass both providers:
```hcl
module "website" {
  providers = {
    aws     = aws
    aws.dns = aws  # Can be the same provider if same account/region
  }
  # ...
}
```

## Runtime Issues

### High Error Rate Alarms

**Symptoms:**
- CloudWatch alarm: "Low Success Rate"
- 5xx errors in ALB access logs

**Diagnosis:**

1. Check ALB access logs:
   ```bash
   aws s3 ls s3://YOUR_ACCESS_LOG_BUCKET/
   ```

2. Look for error patterns:
   ```bash
   # Download and analyze logs
   zcat access_log.gz | grep " 5[0-9][0-9] "
   ```

3. Check target health:
   ```bash
   aws elbv2 describe-target-health --target-group-arn YOUR_TG_ARN
   ```

**Solutions:**

- If instances are unhealthy, check instance logs
- If instances are healthy but returning errors, debug application
- If specific instances are problematic, terminate and let ASG replace

### High Latency Alarms

**Symptoms:**
- CloudWatch alarm: "Target Response Time"
- Slow page loads

**Diagnosis:**

1. Check CloudWatch metrics:
   - `TargetResponseTime` - Time to first byte from targets
   - `RequestCount` - Traffic volume
   - `ActiveConnectionCount` - Concurrent connections

2. Check instance CPU utilization:
   ```bash
   aws cloudwatch get-metric-statistics \
     --namespace AWS/EC2 \
     --metric-name CPUUtilization \
     --dimensions Name=AutoScalingGroupName,Value=YOUR_ASG_NAME \
     --start-time 2024-01-01T00:00:00Z \
     --end-time 2024-01-01T01:00:00Z \
     --period 60 \
     --statistics Average
   ```

**Solutions:**

- Scale up instance type if CPU is consistently high
- Increase `asg_max_size` if hitting scaling limits
- Optimize application code for slow endpoints
- Consider using `least_outstanding_requests` algorithm:
  ```hcl
  load_balancing_algorithm_type = "least_outstanding_requests"
  ```

### Unhealthy Host Alarms

**Symptoms:**
- CloudWatch alarm: "Unhealthy Host Count"
- Some instances marked unhealthy in target group

**Diagnosis:**

1. Check target group health:
   ```bash
   aws elbv2 describe-target-health --target-group-arn YOUR_TG_ARN
   ```

2. Check instance status:
   ```bash
   aws autoscaling describe-auto-scaling-instances
   ```

3. SSH to unhealthy instance and check:
   - Application is running
   - Health endpoint responds
   - No disk space issues
   - No memory issues

**Solutions:**

- If transient (during deployments), adjust threshold:
  ```hcl
  alarm_unhealthy_host_threshold = 1  # Allow 1 unhealthy during updates
  ```

- If persistent, investigate and fix root cause

### No Email Notifications

**Symptoms:**
- Alarms are firing but no emails received
- SNS subscription shows "PendingConfirmation"

**Solution:**

1. Check for confirmation email in spam folder
2. Resend confirmation:
   ```bash
   aws sns list-subscriptions-by-topic --topic-arn YOUR_SNS_TOPIC_ARN
   ```

3. Or recreate subscription via Terraform (destroy and apply)

## Security Issues

### Cannot SSH to Instances

**Symptoms:**
- SSH connection timeout
- "Connection refused"

**Causes:**
- Security group blocking SSH
- No route to instance (private subnet without bastion)
- Wrong key pair

**Solutions:**

1. Check security group allows SSH:
   ```bash
   aws ec2 describe-security-groups --group-ids YOUR_BACKEND_SG_ID
   ```

2. If in private subnet, use Session Manager:
   ```bash
   aws ssm start-session --target INSTANCE_ID
   ```

3. Or deploy a bastion host in public subnet

4. Add `ssh_cidr_block` for your IP:
   ```hcl
   ssh_cidr_block = "YOUR_IP/32"
   ```

### Certificate Not Working

**Symptoms:**
- Browser shows "Certificate Invalid"
- `curl` fails with SSL error

**Diagnosis:**

1. Check certificate status:
   ```bash
   aws acm describe-certificate --certificate-arn YOUR_CERT_ARN
   ```

2. Verify DNS resolves to ALB:
   ```bash
   dig +short your-domain.com
   ```

3. Test SSL:
   ```bash
   openssl s_client -connect your-domain.com:443 -servername your-domain.com
   ```

**Solutions:**

- If certificate is `PENDING_VALIDATION`, wait for DNS propagation
- If certificate is `FAILED`, check validation records
- If using wrong certificate, verify `dns_a_records` includes all hostnames

## Cost Issues

### Unexpected Charges

**Common causes and solutions:**

1. **ALB charges**: ALBs have hourly charges plus LCU charges
   - Review traffic patterns
   - Consider combining multiple services behind one ALB

2. **Data transfer**: Check CloudWatch for data transfer metrics
   - Enable compression in your application
   - Use CloudFront for static assets

3. **Spot instance interruptions**: Frequent replacements increase costs
   - Increase `on_demand_base_capacity` for stability
   - Use multiple instance types (requires custom configuration)

4. **S3 access logs**: Large log volumes increase storage costs
   - Set up lifecycle rules to delete old logs
   - Consider sampling in high-traffic scenarios

## Getting Help

If you're still experiencing issues:

1. **Check existing issues**: [GitHub Issues](https://github.com/infrahouse/terraform-aws-website-pod/issues)
2. **Open a new issue** with:
   - Terraform version
   - Module version
   - Relevant configuration (sanitized)
   - Error messages
   - Steps to reproduce