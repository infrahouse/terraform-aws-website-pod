data "aws_region" "current" {}

data "cloudinit_config" "frontend_init" {
  gzip          = false
  base64_encode = true

  part {
    content_type = "text/cloud-config"
    content = join(
      "\n",
      [
        "#cloud-config",
        yamlencode(
          {
            apt : {
              sources : {
                infrahouse : {
                  source : "deb [signed-by=$KEY_FILE] https://release-${var.ubuntu_codename}.infrahouse.com/ $RELEASE main"
                  key : file("${path.module}/files/DEB-GPG-KEY-infrahouse-${var.ubuntu_codename}")
                }
              }

            }
            package_update : true,
            packages : [
              "infrahouse-toolkit",
              "net-tools",
              "openssl",
              "xinetd",
            ]
            write_files : [
              {
                path : "/etc/xinetd.d/http"
                permissions : "0600"
                content : file("${path.module}/xinetd.d.http")
              },
              {
                path : "/usr/local/bin/httpd"
                permissions : "0755"
                content : file("${path.module}/httpd.sh")
              },
              {
                path : "/var/local/client.cfg"
                permissions : "0644"
                content : "extendedKeyUsage=clientAuth"
              }
            ]
            runcmd : [
              "cd /var/local/; ih-secrets --aws-region ${data.aws_region.current.name} get ${module.truststore.ca-key-secret-name} > ca.key",
              "cd /var/local/; ih-secrets --aws-region ${data.aws_region.current.name} get ${module.truststore.ca-pem-secret-name} > ca.pem",
              "cd /var/local/; openssl genrsa -aes256 -passout pass:xxxx -out client.pass.key 4096",
              "cd /var/local/; openssl rsa -passin pass:xxxx -in client.pass.key -out client.key",
              "cd /var/local/; openssl req -new -key client.key -out client.csr -subj \"/C=US/ST=Oregon/L=Sunriver/O=My Organization/OU=IT/CN=client.example.com\"",
              "cd /var/local/; openssl x509 -req -days 365 -in client.csr -CA ca.pem -CAkey ca.key -set_serial 01 -extfile client.cfg -out client.pem",
              "cd /var/local/; cat client.key client.pem ca.pem > client.full.pem",
              "rm /var/local/client.pass.key",
              "systemctl start xinetd"
            ]
          }
        )
      ]
    )
  }
}

data "cloudinit_config" "backend_init" {
  gzip          = false
  base64_encode = true

  part {
    content_type = "text/cloud-config"
    content = join(
      "\n",
      [
        "#cloud-config",
        yamlencode(
          {
            package_update : true,
            packages : [
              "xinetd",
              "net-tools"
            ]
            write_files : [
              {
                path : "/etc/xinetd.d/http"
                permissions : "0600"
                content : file("${path.module}/xinetd.d.http")
              },
              {
                path : "/usr/local/bin/httpd"
                permissions : "0755"
                content : file("${path.module}/httpd.sh")
              }
            ]
            runcmd : [
              "systemctl start xinetd"
            ]
          }
        )
      ]
    )
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-${var.ubuntu_codename}-*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name = "state"
    values = [
      "available"
    ]
  }

  owners = ["099720109477"] # Canonical
}

data "aws_iam_policy_document" "webserver_permissions" {
  statement {
    actions   = ["ec2:Describe*"]
    resources = ["*"]
  }
}

data "aws_route53_zone" "website" {
  name = var.dns_zone
}
