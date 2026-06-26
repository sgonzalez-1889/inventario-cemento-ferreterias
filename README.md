# Inventario de Cemento — Ferreterías

App para controlar existencias de cemento por almacén: existencia en sistema vs. conteo físico, con diferencias resaltadas. Solo el rol **admin** puede registrar conteos y existencia; los demás usuarios (**viewer**) solo ven el dashboard de diferencias.

## 1. Crear el proyecto en Supabase

1. Entra a tu proyecto de Supabase (o crea uno nuevo, igual que con tus otras apps).
2. Ve a **SQL Editor** → pega todo el contenido de `schema.sql` → Run.
3. Ve a **Authentication → Providers** y confirma que "Email" esté habilitado.
4. (Opcional pero recomendado) En **Authentication → Settings**, desactiva "Confirm email" mientras pruebas, para no depender de correos de confirmación.

## 2. Crear tu usuario admin

1. En la app (una vez desplegada), regístrate con tu correo desde la pantalla de login.
2. En Supabase, ve a **SQL Editor** y ejecuta:
   ```sql
   update profiles set rol = 'admin' where email = 'tu_correo@ejemplo.com';
   ```
3. Vuelve a entrar a la app (cierra sesión y entra de nuevo) — ahora verás las pestañas de administrador.

Cualquier otra persona que se registre queda como `viewer` automáticamente (solo ve el dashboard). Para dar admin a alguien más, repite el `update` con su correo.

## 3. Desplegar en Vercel (corrigiendo el error 404)

Si subiste solo `App.jsx` al repo, Vercel no tiene nada que compilar (no hay `package.json` ni `index.html`) y por eso la página queda en **404: NOT_FOUND** aunque el deployment diga "Ready". La solución es subir el proyecto completo:

1. En tu repo de GitHub (`inventario-cemento-ferreterias`), sube **toda esta carpeta** manteniendo la estructura exacta:
   ```
   inventario-cemento-ferreterias/
   ├── index.html
   ├── package.json
   ├── vite.config.js
   ├── README.md
   ├── schema.sql
   └── src/
       ├── main.jsx
       └── App.jsx
   ```
2. Abre `src/App.jsx` y reemplaza:
   ```js
   const SUPABASE_URL = 'TU_SUPABASE_URL';
   const SUPABASE_ANON_KEY = 'TU_SUPABASE_ANON_KEY';
   ```
   con tus llaves reales (Project Settings → API en Supabase).
3. Commit a la rama `main`.
4. En Vercel, ve a **Project Settings → General** y confirma:
   - **Framework Preset**: Vite
   - **Build Command**: `vite build` (o `npm run build`)
   - **Output Directory**: `dist`
   - **Root Directory**: `.` (la raíz del repo, donde está `package.json`)
5. Si ya tenías un deployment fallido, ve a **Deployments → ⋯ → Redeploy** (o simplemente vuelve a hacer commit) y luego fuerza recarga (Ctrl+Shift+R).

Una vez que el repo tenga esta estructura completa, los próximos cambios sí pueden ser solo reemplazar `src/App.jsx`, commit y force-reload — como haces normalmente.

## 4. Cómo se usa

- **Almacenes / Productos** (admin): primero crea tus más de 6 puntos de venta y las referencias de cemento que manejas (marca + presentación).
- **Existencia en Sistema** (admin): carga la cantidad que dice el sistema, de dos formas:
  - **Manual**: un almacén/producto a la vez.
  - **Excel**: descarga la plantilla (botón en la pestaña), llena varias filas (`almacen, producto, presentacion, cantidad`) y súbela de una vez. Los nombres de almacén/producto deben coincidir exactamente con los que creaste en el catálogo.
- **Registrar Conteo Físico** (admin): cada vez que se hace un conteo en bodega, se registra aquí. Queda guardado en el histórico — el dashboard siempre compara contra el conteo más reciente.
- **Dashboard / Diferencias** (todos): tabla por almacén y producto mostrando existencia en sistema, último conteo físico, la diferencia y un estado:
  - 🟢 **OK** = coinciden
  - 🔴 **FALTANTE** = el conteo físico es menor que el sistema
  - 🔵 **SOBRANTE** = el conteo físico es mayor que el sistema

## Notas

- Los `viewer` solo tienen permiso de lectura a nivel de base de datos (Row Level Security), así que aunque alguien manipule el código del navegador, no puede escribir datos.
- Si quieres agregar fotos del conteo físico (como en tu app de entregas), se puede sumar una tabla `conteo_fotos` y reutilizar el mismo patrón de subida que ya usas allí — dime si quieres que lo agregue.
