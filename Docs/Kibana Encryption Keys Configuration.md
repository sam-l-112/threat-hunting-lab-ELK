# Kibana Encryption Keys Configuration

This document guide explains how to generate and configure the required encryption keys for Kibana within the K3s environment. These keys are mandatory for features like encrypted saved objects, reporting, and security sessions.

## 1. Generate Encryption Keys

Since Kibana runs inside a K3s cluster, you can generate the keys directly from the running Pod. 

Execute the following command on your K3s control plane:

```bash
kubectl exec -it kibana-kibana-546b7c779-tbx95 -n default -- /usr/share/kibana/bin/kibana-encryption-keys generate
```

The output will look similar to this:

```text
xpack.encryptedSavedObjects.encryptionKey: xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xpack.reporting.encryptionKey: xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xpack.security.encryptionKey: xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

```

## 2. Configure Helm Values

Do **NOT** modify `kibana.yml` directly inside the Pod, as changes will be lost upon restart. Instead, inject these keys as environment variables via Helm.

Open `threat-hunting-lab-ELK/ELK-roles/kibana/values.yml` and append the generated keys to the `extraEnvs` section:

```yaml
extraEnvs:
  - name: "NODE_OPTIONS"
    value: "--max-old-space-size=1800"
  - name: "XPACK_ENCRYPTEDSAVEDOBJECTS_ENCRYPTIONKEY"
    value: "YOUR_GENERATED_KEY_1"
  - name: "XPACK_REPORTING_ENCRYPTIONKEY"
    value: "YOUR_GENERATED_KEY_2"
  - name: "XPACK_SECURITY_ENCRYPTIONKEY"
    value: "YOUR_GENERATED_KEY_3"

```

## 3. Apply Changes

Navigate to the Kibana role directory and upgrade the Helm deployment:

```bash
cd threat-hunting-lab-ELK/ELK-roles/kibana/
helm upgrade kibana elastic/kibana -f values.yml -n default

```

K3s will automatically recreate the Kibana Pod with the new encryption settings applied.