# API de génération de code, entièrement hors ligne à l'exécution

Cette image embarque **Qwen2.5-Coder 7B Instruct**, quantifié en `Q4_K_M`, et
[`llama.cpp`](https://github.com/ggml-org/llama.cpp). Elle expose une API
compatible OpenAI (`/v1/chat/completions`, `/v1/models`) et ne télécharge rien
lorsqu'elle est démarrée.

Le modèle pèse environ 5 Go. Prévoir au moins 8 Go de RAM libre pour une
utilisation confortable avec le contexte par défaut de 8k ; 16 Go est
préférable. Sur CPU, la vitesse dépend fortement du processeur et de la RAM.

## Construire, empaqueter puis installer sans Internet

Ces deux premières commandes nécessitent Internet et Docker sur une machine de
préparation :

```powershell
docker build -t offline-coder-api:qwen2.5-7b-q4km .
docker save -o offline-coder-api.tar offline-coder-api:qwen2.5-7b-q4km
```

Copiez `offline-coder-api.tar` sur la machine isolée, puis chargez et lancez
l'image :

```powershell
docker load -i offline-coder-api.tar
docker run --rm -p 8080:8080 --name coder-api offline-coder-api:qwen2.5-7b-q4km
```

L'API est alors disponible sur `http://127.0.0.1:8080/v1`. Test rapide :

```powershell
Invoke-RestMethod http://127.0.0.1:8080/v1/models
```

Pour garder le conteneur en arrière-plan :

```powershell
docker compose up -d
```

## Paramètres au lancement

Les réglages sont des variables d'environnement ; aucun téléchargement n'est
nécessaire. Exemple avec un contexte plus réduit, adapté à une machine ayant
peu de mémoire :

```powershell
docker run --rm -p 8080:8080 `
  -e CONTEXT_SIZE=4096 `
  -e THREADS=8 `
  -e PARALLEL=1 `
  -e API_KEY=un-secret-local `
  offline-coder-api:qwen2.5-7b-q4km
```

| Variable | Défaut | Rôle |
| --- | ---: | --- |
| `CONTEXT_SIZE` | `8192` | Taille maximale du contexte ; plus grande = plus de RAM. |
| `MODEL_ID` | nom du fichier | Identifiant annoncé par `/v1/models` et à utiliser côté client. |
| `THREADS` | `0` | Threads CPU (`0` laisse `llama.cpp` décider). |
| `PARALLEL` | `1` | Requêtes traitées simultanément ; augmente la mémoire. |
| `API_KEY` | vide | Si renseignée, impose `Authorization: Bearer <clé>`. |
| `N_GPU_LAYERS` | `0` | Réservé à une future image compilée avec support GPU. |

## OpenCode

Copiez ou fusionnez [`examples/opencode.json`](examples/opencode.json) dans la
configuration OpenCode du projet. Le fichier utilise son fournisseur
OpenAI-compatible avec l'URL locale `http://127.0.0.1:8080/v1`.

Si `API_KEY` est défini pour le conteneur, remplacez `local` dans
`settings.apiKey` par la même valeur. Si l'IDE est sur une autre machine,
remplacez `127.0.0.1` par l'adresse IP de l'hôte Docker et protégez le port
avec un pare-feu ou une clé API.

## Faire évoluer le matériel ou le modèle

Le même conteneur est optimisé CPU. Les paramètres CPU et mémoire sont
ajustables au démarrage. Pour passer à un GPU, il faut reconstruire l'image
avec le backend GPU correspondant (CUDA, Vulkan ou autre), puis fixer
`N_GPU_LAYERS` selon la VRAM disponible : un binaire CPU ne peut pas utiliser
un GPU uniquement via une variable d'environnement.

Pour intégrer un autre modèle GGUF, construisez avec son URL et son nom :

```powershell
docker build `
  --build-arg MODEL_URL="https://.../mon-modele.gguf" `
  --build-arg MODEL_FILE="mon-modele.gguf" `
  -t offline-coder-api:custom .
```

Puis lancez l'image avec `-e MODEL=/models/mon-modele.gguf`.
Ajoutez aussi `-e MODEL_ID=mon-modele.gguf` et adaptez le fichier OpenCode.

## Acceleration NVIDIA (RTX A2000)

The CPU image cannot use a GPU only by changing `N_GPU_LAYERS`. Build and run
the CUDA variant instead:

```powershell
# Verify that Docker Desktop passes the NVIDIA GPU into containers.
docker run --rm --gpus all nvidia/cuda:12.8.1-base-ubuntu24.04 nvidia-smi

docker compose -f docker-compose.cuda.yml up --build
```

The RTX A2000 has 4 GB of dedicated VRAM. The CUDA defaults use a 4096-token
context and 16 GPU layers, leaving room for the context cache. Increase
`N_GPU_LAYERS` two at a time only while the server starts without an out of
memory error. Windows shared GPU memory is system RAM and is much slower; it
is not extra VRAM for this purpose. The Intel UHD is not used by this CUDA
variant.
