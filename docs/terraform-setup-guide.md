# Terraform Setup Guide

## 🎯 Vad är Terraform?

Terraform är ett verktyg för att skapa och hantera molnresurser (som EC2-instanser) med kod istället för att klicka i AWS Console. Du skriver konfiguration i `.tf`-filer och Terraform skapar resurserna åt dig.

## 📋 Förutsättningar

- Terraform installerat (`terraform --version` ska fungera)
- AWS CLI konfigurerat (`aws sts get-caller-identity` ska visa ditt konto)
- Ett EC2 Key Pair skapat i AWS Console (eu-west-1 region)

## 🔧 Första gången: Setup

### 1. Uppdatera key pair namnet

Öppna `terraform/main.tf` och ändra på **två ställen**:

```terraform
key_name = "your-key-name"  # ÄNDRA till ditt riktiga key pair namn
```

Till exempel:

```terraform
key_name = "dennis-key-pair"
```

### 2. Initiera Terraform

Kör detta **EN GÅNG** i början:

```bash
cd terraform
terraform init
```

Detta laddar ner AWS-providern som Terraform behöver.

## 🚀 Använda Terraform

### Grundläggande kommandon

Kör alltid från `terraform/` mappen:

```bash
cd terraform
```

### 1. Planera (se vad som kommer hända)

```bash
terraform plan
```

Detta visar vad Terraform kommer att skapa/ändra/ta bort, men gör **ingenting** ännu.

### 2. Skapa resurserna

```bash
terraform apply
```

- Terraform visar planen igen
- Skriv `yes` för att bekräfta
- Vänta medan resurserna skapas (2-3 minuter)

### 3. Se IP-adresser

Efter `terraform apply` ser du IP-adresserna:

```
Outputs:

manager_ip = "54.123.45.67"
worker_ips = [
  "54.123.45.68",
  "54.123.45.69"
]
```

**Spara dessa IP-adresser** - du behöver dem för SSH!

### 4. Ta bort allt

När du är klar:

```bash
terraform destroy
```

- Skriv `yes` för att bekräfta
- Alla AWS-resurser tas bort (ingen kostnad längre)

## 📝 Vanliga kommandon

```bash
# Se vad som finns (utan att ändra något)
terraform plan

# Skapa/uppdatera resurser
terraform apply

# Se nuvarande status
terraform show

# Se bara outputs
terraform output

# Ta bort allt
terraform destroy
```

## 🛠️ Felsökning

### "No valid credential sources found"

**Problem:** AWS CLI inte konfigurerat
**Lösning:**

```bash
aws configure
# Ange dina AWS Access Key, Secret, region (eu-west-1)
```

### "KeyPair does not exist"

**Problem:** Key pair namnet stämmer inte
**Lösning:**

1. Gå till AWS Console → EC2 → Key Pairs
2. Se vilket namn ditt key pair har
3. Uppdatera `key_name` i `main.tf`

### "InvalidGroup.NotFound"

**Problem:** Security group redan finns med samma namn
**Lösning:**

```bash
terraform destroy  # Ta bort gamla resurser först
terraform apply     # Skapa nya
```

### AMI inte hittas

**Problem:** AMI-ID är fel för regionen
**Lösning:** AMI `ami-0c38b837cd80f13bb` är för eu-west-1. Om du använder annan region, hitta rätt AMI i AWS Console.

## 🔄 Typiskt arbetsflöde

1. **Första gången:**

   ```bash
   cd terraform
   terraform init
   # Ändra key_name i main.tf
   terraform plan
   terraform apply
   ```

2. **Nästa gånger:**

   ```bash
   cd terraform
   terraform plan    # Kolla vad som händer
   terraform apply   # Skapa resurserna
   # ... använd resurserna (SSH, Docker Swarm, etc)
   terraform destroy # Ta bort när du är klar
   ```

3. **Om du ändrar i main.tf:**
   ```bash
   terraform plan    # Se förändringarna
   terraform apply   # Applicera ändringarna
   ```

## 💡 Tips

- **Kör alltid `terraform plan` först** för att se vad som händer
- **Spara IP-adresserna** från output - du behöver dem för SSH
- **Kör `terraform destroy`** när du är klar för att spara pengar
- **Backup:** Git committa dina `.tf`-filer (men aldrig `.tfstate`-filer)

## 📁 Filstruktur

```
terraform/
├── main.tf           # All konfiguration (det enda du behöver ändra)
├── .terraform/       # Terraform cache (ignorera)
├── terraform.tfstate # Terraform state (viktigt, gör backup)
└── terraform.tfstate.backup
```

**Viktigt:** Committa `main.tf` till Git, men **inte** `.terraform/` eller `*.tfstate*`.

## 🎯 Nästa steg

Efter `terraform apply`:

1. **SSH till manager:** `ssh -i ~/.ssh/din-nyckel.pem ec2-user@<manager-ip>`
2. **Följ Docker Swarm guiden:** `docs/docker-swarm-on-aws.md`
3. **När du är klar:** `terraform destroy`
