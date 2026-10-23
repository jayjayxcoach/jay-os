# JAY OS

Centro de proyectos del equipo: proyectos, tareas, línea de tiempo y semana en un solo lugar.

- **Página:** `index.html`, publicada con GitHub Pages.
- **Datos:** Supabase, proyecto `jay-os`. Cada persona entra con su correo y su contraseña.
- **Base de datos:** `supabase/01_esquema.sql` crea las tablas, la seguridad y el tiempo real.

## Cómo entra alguien nuevo

1. En Supabase: **Authentication → Users → Add user → Create new user**, con su correo y una contraseña, marcando *Auto Confirm User*.
2. En JAY OS: **Equipo → +**, con el mismo correo.
3. La persona entra en la página y puede cambiar su contraseña desde *Mi cuenta*.

La llave que aparece en `index.html` es la pública de Supabase. Sin usuario y sin estar en el equipo no se puede leer ni cambiar nada.
