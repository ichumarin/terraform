resource "aws_key_pair" "bastion" {
  key_name   = var.key_name
  public_key = file("~/.ssh/id_rsa.pub")
}

resource "aws_security_group" "nagios_server_tls" {
  name        = var.sec_group_name
  description = "Allow TLS inbound traffic"
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "aws_instance" "nagios_server" {
  ami                    = data.aws_ami.centos.id
  instance_type          = var.instance_type
  availability_zone      = data.aws_availability_zones.all.names[0]
  vpc_security_group_ids = [aws_security_group.nagios_server_tls.id]
  key_name               = aws_key_pair.bastion.key_name
}

resource "null_resource" "commands" {
  depends_on = [aws_instance.nagios_server, aws_security_group.nagios_server_tls]
  triggers = {
    always_run = timestamp()
  }
 
  # Execute linux commands on remote machine
  provisioner "remote-exec" {
    connection {
      host        = aws_instance.nagios_server.public_ip
      type        = "ssh"
      user        = "centos"
      private_key = file("~/.ssh/id_rsa")
    }
    inline = [
      "sudo yum install wget -y",
      "sudo wget -O /tmp/xi-latest.tar.gz  https://assets.nagios.com/downloads/nagiosxi/xi-latest.tar.gz",
      "sudo  /tmp/tar xzf xi-latest.tar.gz",
      "sudo bash /tmp/nagiosxi/fullinstall"
    ]
  }
}