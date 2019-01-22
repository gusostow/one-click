provider "aws" {
    region = "us-west-2"
}

resource aws_key_pair "one_click" {
    key_name = "one-click-key"
    public_key = "${file("${var.path_to_public_key}")}"
}

resource "aws_instance" "flask_server" {
    ami = "ami-70e90210",
    instance_type = "t2.medium"
    key_name = "${aws_key_pair.one_click.key_name}"

    vpc_security_group_ids = ["${aws_security_group.allow_flask_and_ssh.id}"]

    tags {
        Name = "flask-server"
    }

    connection {
            type = "ssh"
            user = "ubuntu"
            private_key = "${file("${var.path_to_private_key}")}"
    }

    provisioner "remote-exec" {
        inline = [
            "mkdir root",
            "echo '${file("./docker-compose.yml")}' > root/docker-compose.yml",
            "echo '${file("./Dockerfile")}' > root/Dockerfile",
            "mkdir root/app",
            "echo '${file("./uwsgi.ini")}' > root/app/uwsgi.ini",
        ]
    }

    provisioner "file" {
        source = "${var.path_to_app}/"
        destination = "/home/ubuntu/root/app"
    }

    provisioner "remote-exec" {
        inline = [
            "sudo apt-get update && sudo apt-get install -y docker.io",
            "sudo curl -L https://github.com/docker/compose/releases/download/1.18.0/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose",
            "sudo chmod +x /usr/local/bin/docker-compose",
            "cd root",
            "sudo docker-compose up -d"
        ]
    }
}

resource "aws_security_group" "allow_flask_and_ssh" {
    name = "allow_flask_and_ssh"

    ingress {
        protocol = "tcp"
        from_port = 80
        to_port = 80
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        protocol = "tcp"
        from_port = 22
        to_port = 22
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        protocol = "tcp"
        from_port = 0
        to_port = 65535
        cidr_blocks = ["0.0.0.0/0"]
    }
}

variable "path_to_app" {}

variable "path_to_public_key" {}

variable "path_to_private_key" {}

output "public_ip" {
    value = "${aws_instance.flask_server.public_ip}"
}

output "public_dns" {
    value = "${aws_instance.flask_server.public_dns}"
}
