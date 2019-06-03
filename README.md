# ci-pipeline-demo

Este repositorio contiene el código usado en la demostración de CI del pasado 31 de Mayo de 2019.

## Utilizacion de este repositorio

### Requisitos

- Un repositorio de Gitlab.com
- Una cuenta Free de Terraform Enterprise (para alojar los tfstate)
- Un token de API de Terraform Enterprise
- Crear una variable de entorno en el CI de Gitlab.com con el nombre TEAMTOKEN y con el contenido del token de API de Terraform
- Unas credenciales de AWS en formato Acess Key y Secret Key
- Una clave de SSH en formato PEM


### Como probarlo

1. Clonar este repositorio
2. Sustituir los valores en main.tf y provider.tfvars.
3. Hacer commit y push del repositorio en Gitlab.com
4. En la web de Gitlab.com acceder a los pipelines del repositorio
5. Esperar unos 5 minutos y comprobar el nombre DNS del ELB que debería estar sirviendo la web.
6. Hacer cambios en el main.tf (por ejemplo cambiar el número de instancias)
7. Hacer commit y push del repositorio
8. Revisar que se han aplicado los cambios
