# настройки провайдера
terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 0.13"
}

provider "yandex" {
  zone = "ru-central1-a"
}

locals {
  folder_id = "b1g0pkgs2tni2jv71d47"
}

# настройки ресурсов
data "yandex_compute_image" "ubuntu" {
  family = "ubuntu-2204-lts"
}

# диски
resource "yandex_compute_disk" "boot-disk-1" {
  name     = "boot-disk-1"
  type     = "network-ssd"
  size     = "20"
  image_id = data.yandex_compute_image.ubuntu.image_id
}

resource "yandex_compute_disk" "boot-disk-2" {
  name     = "boot-disk-2"
  type     = "network-ssd"
  size     = "20"
  image_id = data.yandex_compute_image.ubuntu.image_id
}


# ВМ для домена "Клиника"
resource "yandex_compute_instance" "vm-1" {
  name = "medical-domain-servers"

  resources {
    cores  = 8
    memory = 16
  }

  boot_disk {
    disk_id = yandex_compute_disk.boot-disk-1.id
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet-1.id
    nat       = true
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/ssh-key-1766183480845.pub")}"
  }
}

# ВМ для домена "Финансы"
resource "yandex_compute_instance" "vm-2" {
  name = "finance-domain-servers"

  resources {
    cores  = 8
    memory = 16
  }

  boot_disk {
    disk_id = yandex_compute_disk.boot-disk-2.id
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet-1.id
    nat       = true
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/ssh-key-1766183480845.pub")}"
  }
}

# Аналогично создаются ВМ для других доменов
#...

# kafka. закомментил, поскольку кластер долго создается
# resource "yandex_mdb_kafka_cluster" "my_cluster" {
#   name        = "test"
#   environment = "PRESTABLE"
#   network_id  = yandex_vpc_network.network-1.id

#   config {
#     version          = "3.6"
#     brokers_count    = 1
#     zones            = ["ru-central1-a"]
#     assign_public_ip = false
#     schema_registry  = false
#     rest_api {
#       enabled = true
#     }
#     kafka_ui {
#       enabled = true
#     }
#     kafka {
#       resources {
#         resource_preset_id = "s2.micro"
#         disk_type_id       = "network-ssd"
#         disk_size          = 32
#       }
#       kafka_config {
#         compression_type                = var.kafka_compression_type
#         log_flush_interval_messages     = 1024
#         log_flush_interval_ms           = 1000
#         log_flush_scheduler_interval_ms = 1000
#         log_retention_bytes             = 1073741824
#         log_retention_hours             = 168
#         log_retention_minutes           = 10080
#         log_retention_ms                = 86400000
#         log_segment_bytes               = 134217728
#         num_partitions                  = 10
#         default_replication_factor      = 1
#         message_max_bytes               = 1048588
#         replica_fetch_max_bytes         = 1048576
#         ssl_cipher_suites               = ["TLS_DHE_RSA_WITH_AES_128_CBC_SHA", "TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256"]
#         offsets_retention_minutes       = 10080
#         sasl_enabled_mechanisms         = ["SASL_MECHANISM_SCRAM_SHA_256", "SASL_MECHANISM_SCRAM_SHA_512"]
#       }
#     }
#   }
# }



# S3
#  Create SA
resource "yandex_iam_service_account" "sa" {
  folder_id = local.folder_id
  name      = "tf-test-sa"
}

# Grant permissions
resource "yandex_resourcemanager_folder_iam_member" "sa-editor" {
  folder_id = local.folder_id
  role      = "storage.editor"
  member    = "serviceAccount:${yandex_iam_service_account.sa.id}"
}

# Create Static Access Keys
resource "yandex_iam_service_account_static_access_key" "sa-static-key" {
  service_account_id = yandex_iam_service_account.sa.id
  description        = "static access key for object storage"
}

# Use keys to create bucket
resource "yandex_storage_bucket" "test" {
  access_key = yandex_iam_service_account_static_access_key.sa-static-key.access_key
  secret_key = yandex_iam_service_account_static_access_key.sa-static-key.secret_key
  bucket     = "tf-test-bucket"
}


# сеть
resource "yandex_vpc_network" "network-1" {
  name = "network1"
}

resource "yandex_vpc_subnet" "subnet-1" {
  name           = "subnet1"
  network_id     = yandex_vpc_network.network-1.id
  v4_cidr_blocks = ["192.168.10.0/24"]
}