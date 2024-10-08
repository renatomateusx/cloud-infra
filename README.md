# Infraestrutura na Nuvem com Terraform

Este repositório contém configurações Terraform para provisionar e gerenciar uma infraestrutura básica na AWS, incluindo máquinas virtuais (EC2), banco de dados gerenciado (RDS) e balanceador de carga (ELB), Multi A-Z.

## Pré-requisitos

- [Terraform](https://www.terraform.io/downloads.html)
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html)

## Instalação

1.1 Clone este repositório:
   git clone https://github.com/seu_usuario/cloud-infra.git
   cd cloud-infra

1.2. Inicialize o Terraform:

    terraform init

1.3. Visualize o plano de execução:  
    terraform plan

1.4. Aplique a configuração:

    terraform apply

1.5 Para destruir a infraestrutura:

    terraform destroy


### 3. **Documentação Adicional**

Pending `docs/` .

#### **`docs/architecture.md`**

Pending arch.

**Exemplo:**

# Arquitetura

## Diagrama de Arquitetura

[draw.io]

## Descrição

Esta configuração utiliza múltiplas zonas de disponibilidade para garantir alta disponibilidade e resiliência. As instâncias EC2 são provisionadas em três AZs para distribuir a carga. O banco de dados RDS é configurado com alta disponibilidade usando a opção `multi_az`.

- **EC2 Instances**: Distribuídas em várias AZs para resiliência.
- **RDS**: Configurado para alta disponibilidade com `multi_az`.
- **ELB**: Balanceia o tráfego entre as instâncias EC2.


# Segurança

## Regras de Grupos de Segurança

Os grupos de segurança são configurados para permitir apenas tráfego necessário:
- **Porta 80 (HTTP)**: Permitido para tráfego de qualquer origem.
- **Porta 22 (SSH)**: Permitido apenas para IPs específicos em um ambiente de produção.

## Criptografia

- **Volumes EBS**: Criptografados para proteção de dados em repouso.
- **Banco de Dados RDS**: Criptografado com `storage_encrypted = true`.

## Backup e Recuperação

- **Backups Automáticos**: Habilitados para o RDS com uma retenção de 7 dias.

# Escalabilidade

## Grupo de Auto Scaling

O grupo de Auto Scaling é configurado para ajustar o número de instâncias EC2 com base na carga:

- **Min Size**: 2 instâncias
- **Max Size**: 4 instâncias
- **Políticas de Escalabilidade**: Aumenta o número de instâncias quando a CPU excede 80% e diminui quando cai abaixo de 50%.

## Configuração

```hcl
resource "aws_launch_configuration" "web" {
  name          = "web-launch-configuration"
  image_id      = "ami-0c55b159cbfafe1f0"
  instance_type = var.instance_type
  key_name      = aws_key_pair.deployer.key_name
  security_groups = [aws_security_group.web_sg.name]

  lifecycle {
    create_before_destroy = true
  }
}
```

