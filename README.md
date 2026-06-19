# potencia-sfp-prometheus

Exporter de Prometheus que recolecta métricas de potencia óptica (SFP) de switches Dell EMC via SSH.

Expone métricas de **rx-power**, **tx-power** y **tx-bias-current** por interfaz y sub-puerto en formato Prometheus en `/metrics`.

## Estructura del repositorio

```
├── app/                    # Código fuente y build de la imagen Docker
│   ├── Dockerfile
│   ├── build-image.sh
│   ├── requirements.txt
│   ├── potencia-prometehus-cm.py
│   └── element.ssh           # Mapeo IP -> nombre de switch
├── deploy/                 # Helm chart + manifiesto ArgoCD
│   ├── Chart.yaml
│   ├── values.yaml
│   ├── custom-values.yaml
│   ├── templates/
│   └── argocd/
│       └── application.yaml
└── samples/
```

## Build de la imagen

```sh
cd app
./build-image.sh
```

Requiere Docker o Podman. Pushea la imagen a `happiolaza/potencia-sfp-prometehus-cm:1.4` (configurable en `deploy/values.yaml`).

## Despliegue con Helm

```sh
cd deploy
helm upgrade --install potencia-sfp-barracas . \
  --namespace grafana-operaciones \
  --create-namespace
```

Usa `values.yaml` por defecto. Para usar la config específica de Barracas:

```sh
helm upgrade --install potencia-sfp-barracas . \
  --namespace grafana-operaciones \
  --create-namespace \
  -f custom-values.yaml
```

### Credenciales SSH

Antes de desplegar, crear un Secret con las credenciales de los switches:

```sh
kubectl create secret generic potencia-sfp-barracas-ssh \
  --namespace grafana-operaciones \
  --from-literal=username=<usuario> \
  --from-literal=password=<password>
```

El nombre del Secret se forma como `<fullname>-ssh`. Se puede overridear con `existingSecret` en values.

## Despliegue con ArgoCD

El manifiesto `deploy/argocd/application.yaml` define un Application de ArgoCD que apunta a la carpeta `deploy/` del repositorio.

Para aplicarlo:

```sh
kubectl apply -f deploy/argocd/application.yaml
```

Esto crea un Application en el namespace `argocd`. ArgoCD se encarga del sync automático con las siguientes políticas:

- **Auto-prune**: elimina recursos que ya no están en el chart
- **Self-heal**: revierte cambios manuales al estado del repositorio
- **CreateNamespace**: crea `grafana-operaciones` si no existe
- **Retry**: hasta 5 reintentos con backoff exponencial

### Requisitos para ArgoCD

1. ArgoCD instalado en el cluster
2. El Application usa `https://whitecicd-tt.cuyows.tcloud.ar/operaciones-red-cloud/potencia-sfp-prometheus.git` como source. Si se cambia de repo, actualizar `deploy/argocd/application.yaml`
3. Las credenciales SSH deben existir como Secret antes del sync (ver sección anterior)

### Push a ambos repositorios

El repo se sincroniza con GitHub y GitLab:

```sh
git push origin main      # GitHub
git push gitlab main      # GitLab
```
