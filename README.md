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

## Flujo completo (CI/CD → ArgoCD)

```
git push a GitLab
       │
       ▼
┌─────────────────────┐
│  Pipeline CI         │
│  1. build + push     │
│     imagen a Harbor  │
│  2. update tag en    │
│     values.yaml      │
│  3. commit [skip ci] │
└────────┬────────────┘
         │ push con nuevo tag
         ▼
┌─────────────────────┐
│  ArgoCD detecta     │
│  cambio en git      │
│  → sync automático  │
│  → rollout nueva    │
│     versión         │
└─────────────────────┘
```

## Build de la imagen

### Manual (local)

```sh
cd app
./build-image.sh
```

Requiere Docker o Podman. Pushea la imagen a `happiolaza/potencia-sfp-prometehus-cm:1.4`.

### Automático (GitLab CI)

Al pushear a `main` en GitLab, el pipeline:
1. Buildéa la imagen con Kaniko usando la base de Harbor
2. Pushea a Harbor: `power-metrics/potencia-sfp-prometehus-cm:<sha>` y `latest`
3. Actualiza `deploy/values.yaml` con el nuevo SHA y lo commitea con `[skip ci]`
4. ArgoCD detecta el cambio y sincroniza automáticamente

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

## CI/CD Pipeline (GitLab)

El pipeline buildea la imagen Docker automáticamente al pushear a `main` en GitLab.

### Infraestructura

| Componente | URL |
|-----------|-----|
| GitLab | `https://whitecicd-tt.cuyows.tcloud.ar` |
| Harbor (registry) | `https://whiteregistry.cuyows.tcloud.ar` |

### Proyectos en Harbor

| Proyecto | Uso |
|----------|-----|
| `whitecicd-pipeline` | Imágenes helper del CI (kaniko, base con pip) |
| `power-metrics` | Imagen final de la aplicación |

### Imágenes disponibles

| Imagen | Descripción |
|--------|-------------|
| `whitecicd-pipeline/kaniko-git:debug` | Kaniko + git, usada por el runner para buildear |
| `whitecicd-pipeline/python-sfp-base:3.11` | Python 3.11 slim con dependencias pre-instaladas |
| `power-metrics/potencia-sfp-prometehus-cm` | Imagen final de la app (output del pipeline) |

### Cómo funciona el pipeline

1. El runner de GitLab (Kubernetes executor) levanta un pod con la imagen `kaniko-git`
2. Clona el repo usando un **deploy token** (`GIT_DEPLOY_TOKEN`)
3. Kaniko buildea la imagen usando la base de Harbor (sin `pip install`)
4. Pushea la imagen final a Harbor con tags: `latest` + SHA del commit

### Disparar el pipeline manualmente

1. Ir a **Build > Pipelines** en el proyecto de GitLab
2. Click en **Run pipeline**
3. Seleccionar `main` y click en **Run pipeline**

O automáticamente con cada `git push` a `main`:

```sh
git push gitlab main
```

### Variables de CI/CD necesarias

Configuradas en **Settings > CI/CD > Variables** del proyecto:

| Variable | Valor | Masked |
|----------|-------|--------|
| `GIT_DEPLOY_TOKEN` | Token de deploy con scope `read_repository` | ✅ |
| `HARBOR_USER` | Usuario de Harbor | ✅ |
| `HARBOR_PASSWORD` | Password de Harbor | ✅ |

> Nota: La autenticación a Harbor está hardcodeada temporalmente en `.gitlab-ci.yml`. Las variables `HARBOR_USER`/`HARBOR_PASSWORD` están definidas pero aún no se usan en el pipeline (el auth se genera inline). Pendiente de migrar.

### Deploy token

Creado via API con scope `read_repository`. Si expira o se pierde, regenerar:

```sh
curl -X POST --header "PRIVATE-TOKEN: <token>" \
  "https://whitecicd-tt.cuyows.tcloud.ar/api/v4/projects/195/deploy_tokens" \
  -d "name=gitlab-runner-token&scopes[]=read_repository"
```

### Troubleshooting

#### El runner no puede clonar el repo
- Verificar que `GIT_DEPLOY_TOKEN` esté configurada y no marcada como **Protected**
- Verificar que el token no haya expirado

#### Error de certificado TLS con Harbor
- El registry usa certificado self-signed. Kaniko lo saltea con `--skip-tls-verify-registry`

#### pip install falla por red
- El runner no tiene acceso a PyPI. Las dependencias se pre-instalan en la imagen base `python-sfp-base` que se buildéo localmente y subió a Harbor
- Si cambian las dependencias, rebuildear la base localmente:
  ```sh
  docker build -t whiteregistry.cuyows.tcloud.ar/whitecicd-pipeline/python-sfp-base:3.11 -f app/Dockerfile.base app/
  docker push whiteregistry.cuyows.tcloud.ar/whitecicd-pipeline/python-sfp-base:3.11
  ```