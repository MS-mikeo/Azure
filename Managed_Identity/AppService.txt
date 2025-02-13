https://learn.microsoft.com/en-us/azure/app-service/overview-managed-identity?tabs=portal%2Chttp#connect-to-azure-services-in-app-code

Using System Assigned Managed Identity:<br>

1.) Go to the kudo page for the app and then SSH<br>
2.) Enter env in the console to display environment variables<br>
3.) Copy IDENTITY_HEADER and IDENTITY_ENDPOINT <br>
4.) Use this to form requests below.  curl can be used from the ssh connection<br>

Example:<br>
GET /MSI/token?resource=https://vault.azure.net&api-version=2019-08-01 HTTP/1.1<br>
Host: <ip-address-:-port-in-IDENTITY_ENDPOINT> <br>
X-IDENTITY-HEADER: <value-of-IDENTITY_HEADER> <br>

Variable Examples: <br>
IDENTITY_ENDPOINT=http://169.254.444.4:8081/msi/token <br>
IDENTITY_HEADER=5f354567-23ce-48c5-b046-d9e4cdcxxxxxxx <br>

System Assigned Managed Identity:<br>
curl -X GET "http://169.254.444.4:8081/msi/token?api-version=2019-08-01&resource=https://management.azure.com/" \ <br>
     -H "Host: 169.254.444.4:8081" \ <br>
     -H "X-IDENTITY-HEADER: 5f354567-23ce-48c5-b046-d9e4cdcxxxxxxx" <br><br>

User Assigned Managed Identity (note client_id in request):<br>
curl -X GET "http://169.254.129.4:8081/msi/token?api-version=2019-08-01&resource=https://management.azure.com/&client_id=ad4b498e-eef2-4090-90c4-xxxxxxx" \ <br>
     -H "Host: 169.254.444.4:8081" \ <br>
     -H "X-IDENTITY-HEADER: 5f354567-23ce-48c5-b046-d9e4cdcxxxxxxx" <br>
