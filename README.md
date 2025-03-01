# cloudflare-tunnel-terraform
> remotely connect to locally running Docker containers using Cloudflare Tunnel powered by Terraform

## Why?
For this effort, I decided to use [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/) to connect the AI apps to the internet so that I can have my friends try out the AI apps effortlessly (just to be part of the approved Google email group in [Cloudflare Zero Trust](https://developers.cloudflare.com/cloudflare-one/) zone). Also, I didn't want to pay for cloud server costs when I could just use my own hardware.

## Requirements
- [Terraform](https://developer.hashicorp.com/terraform/install)
- [Docker](https://www.docker.com)
- [Cloudflare account](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/deployment-guides/terraform/)

When creating your Cloudflare API token, set the following permissions:
| Permission type	| Permission                | Access level |
| :---------------  | :-----------------------: | :----------: |
| Account	        | Cloudflare Tunnel	        | Edit         |
| Account	        | Access: Apps and Policies	| Edit         |
| Zone	            | DNS	                    | Edit         |

## Usage
To apply the Cloudflare Tunnel terraform plan, run the following command:
```bash
make apply
```

To see the Cloudflare Tunnel terraform plan, run the following command:
```bash
make plan
```

To destroy the Cloudflare Tunnel terraform plan, run the following command:
```bash
make destory
```
