# Arquitetura AWS com Terraform e Monitoramento Grafana

## 📋 Descrição do Projeto

Projeto desenvolvido para a disciplina **Computação em Nuvem II**, sob orientação do Professor **JOSEFFE DE OLIVEIRA (Perigoso)**.

Este projeto implementa uma arquitetura completa na AWS utilizando Infrastructure as Code (IaC) com Terraform, incluindo monitoramento em tempo real através do Grafana.

---

## 👥 Integrantes

- **Pedro Wolski**
- **Thiago Souza**

---

## 📐 Componentes da Atividade

### 1. **Desenho de Arquitetura** (2 pontos)
Arquitetura completa contendo os seguintes serviços AWS:
- **EC2** - Instâncias de computação
- **RDS** - Banco de dados relacional
- **S3** - Armazenamento de objetos
- **ECS** - Container Orchestration
- **Lambda** - Funções serverless
- **API Gateway** - Gerenciamento de APIs
- Serviços adicionais conforme necessidade

### 2. **Script Terraform** (6 pontos)
Script IaC capaz de provisionar toda a arquitetura AWS com os seguintes comandos:
```bash
terraform init      # Inicializa o ambiente Terraform
terraform plan      # Visualiza as mudanças a serem aplicadas
terraform apply     # Aplica a configuração na AWS
```

**Características:**
- Provisionamento automático de todos os serviços
- Configurações parametrizadas através de `terraform.tfvars`
- Gerenciamento de estado com `terraform.tfstate`

### 3. **Dashboards Grafana** (2 pontos)
Monitoramento visual de todos os serviços AWS criados, incluindo:
- Métricas de EC2 (CPU, memória, disco)
- Saúde e desempenho de RDS
- Monitoramento de Lambda (execuções, erros, duração)
- Métricas de S3 (tamanho, requisições)
- Status do ECS e Container Health
- Latência e taxa de erro da API Gateway

---

## 📁 Estrutura do Projeto

```
sysAWS/
├── main.tf                    # Configuração principal do Terraform
├── terraform.tfvars           # Variáveis de entrada
├── terraform.tfstate          # Estado da infraestrutura
├── terraform.tfstate.backup   # Backup do estado
├── diagrama/                  # Desenhos da arquitetura
├── grafana/                   # Configurações do Grafana
│   └── jsonAPI/               # Dashboards em JSON
│       ├── API.json           # Dashboard API Gateway
│       ├── EC2.json           # Dashboard EC2
│       ├── Lambda.json        # Dashboard Lambda
│       ├── RDS.json           # Dashboard RDS
│       └── S3.json            # Dashboard S3
└── README.md                  # Este arquivo
```

---

## 🚀 Como Utilizar

### Pré-requisitos
- Terraform instalado (v1.0+)
- AWS CLI configurado com credenciais válidas
- Grafana instalado e rodando (para monitoramento)

### Passos para Deployment

1. **Inicializar Terraform:**
   ```bash
   terraform init
   ```

2. **Visualizar o plano de execução:**
   ```bash
   terraform plan
   ```

3. **Aplicar a configuração:**
   ```bash
   terraform apply
   ```

4. **Configurar Grafana:**
   - Importar os dashboards JSON localizados em `grafana/jsonAPI/`
   - Configurar data sources para CloudWatch da AWS

---

## 📊 Monitoramento

Os dashboards Grafana fornecerão visualização em tempo real de:
- **EC2**: Utilização de recursos, status de instâncias
- **RDS**: Conexões ativas, latência de queries, taxa de erro
- **Lambda**: Invocações, duração de execução, erros
- **S3**: Requisições, tamanho de buckets
- **API Gateway**: Requisições, latência, erros 4xx/5xx

---

## 🔧 Tecnologias Utilizadas

| Tecnologia | Versão | Propósito |
|---|---|---|
| Terraform | 1.0+ | Infrastructure as Code |
| AWS | Latest | Serviços em Nuvem |
| Grafana | Latest | Monitoramento e Visualização |
| CloudWatch | - | Coleta de Métricas |

---

## 📝 Notas Importantes

- As credenciais AWS devem estar configuradas antes de executar Terraform
- O arquivo `terraform.tfstate` contém informações sensíveis - nunca fazer commit em repositórios públicos
- Os dashboards Grafana precisam de data sources CloudWatch configurados
- Revisar `terraform.tfvars` antes de aplicar para garantir valores corretos

---

**Disciplina:** Computação em Nuvem II  
**Professor:** JOSEFFE DE OLIVEIRA (Perigoso)  
**Data:** 2025
