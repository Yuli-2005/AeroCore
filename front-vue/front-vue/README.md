# Sistema de Vuelos - Frontend Vue 3 + TypeScript + Vite

Este es el nuevo frontend del **Sistema de Vuelos**, migrado desde Angular hacia **Vue 3** utilizando **Composition API (`<script setup>`)**, **TypeScript** y **Vite**.

## Requisitos Previos

Asegúrate de tener instalado [Node.js](https://nodejs.org/) (versión 18 o superior recomendada) y npm en tu sistema.

## Configuración y Arranque

Sigue estos sencillos pasos para instalar las dependencias y arrancar la aplicación en tu entorno local:

### 1. Instalación de Dependencias

Ejecuta el siguiente comando en la raíz del directorio `front-vue` para descargar e instalar todas las dependencias del proyecto:

```bash
npm install
```

### 2. Iniciar el Servidor de Desarrollo

Una vez completada la instalación, inicia el servidor de desarrollo local con:

```bash
npm run dev
```

Este comando levantará la aplicación en un servidor local (por lo general, en `http://localhost:5173/`). Abre esa dirección en tu navegador preferido para ver la aplicación ejecutarse en tiempo real con recarga rápida (HMR).

---

## Comandos Adicionales del Proyecto

* **Compilación para Producción**: Genera el bundle de archivos optimizados, minificados y listos para producción en la carpeta `dist/`.
  ```bash
  npm run build
  ```

* **Verificación de Tipos (TypeScript)**: Ejecuta una comprobación estricta de tipos de TypeScript en toda la aplicación sin generar archivos de salida.
  ```bash
  npx vue-tsc --noEmit
  ```

* **Vista Previa de Producción**: Levanta un servidor local apuntando al bundle generado en `dist/` para probar el rendimiento de producción localmente.
  ```bash
  npm run preview
  ```
