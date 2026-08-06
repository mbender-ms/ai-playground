---
title: Configure an example resource
description: Learn how to configure an example resource by using commands in the Azure command-line interface.
ms.topic: how-to
ms.date: 07/17/2026
author: example-author
ms.author: example
ms.service: azure-example
ai-usage: ai-assisted
---

# Configure an example resource

Configure an example resource from a command line.

## Prerequisites

- An Azure subscription.
- Azure CLI installed.

> [!NOTE]
> This fixture intentionally contains several alerts.

> [!TIP]
> Use a test subscription.

> [!IMPORTANT]
> Review the command before you run it.

## Configure the resource

```bash
az group create --name example-rg --location westus2
```

## Verify the resource

Run `az group show --name example-rg` and confirm that the provisioning state is `Succeeded`.
