import os, json
from PIL import Image, ImageDraw

output_dir = r"c:\ANTIGRAVITY\RemoteTv\App\Assets.xcassets\AppIcon.appiconset"
os.makedirs(output_dir, exist_ok=True)

def create_base_icon(size=1024):
    img = Image.new("RGBA", (size, size), (248, 249, 250, 255))
    draw = ImageDraw.Draw(img)

    # 1. Borde redondeado sutil de la tarjeta interior
    margin = size * 0.08
    # 2. Silueta minimalista del control remoto blanco/gris
    rw = size * 0.44
    rh = size * 0.82
    rx = (size - rw) / 2
    ry = (size - rh) / 2
    rcorner = size * 0.12

    # Sombra del control
    for i in range(12):
        alpha = int(18 - i * 1.4)
        offset = i * 2.5
        draw.rounded_rectangle(
            [rx - i, ry - i + offset, rx + rw + i, ry + rh + i + offset],
            radius=int(rcorner + i),
            fill=(20, 30, 50, alpha)
        )

    # Cuerpo del control remoto (Blanco puro con borde)
    draw.rounded_rectangle(
        [rx, ry, rx + rw, ry + rh],
        radius=int(rcorner),
        fill=(255, 255, 255, 255),
        outline=(220, 224, 230, 255),
        width=int(size * 0.008)
    )

    # Botón Power (punto rojo sutil arriba a la derecha)
    pw_size = size * 0.04
    pw_x = rx + rw - pw_size - size * 0.06
    pw_y = ry + size * 0.06
    draw.ellipse([pw_x, pw_y, pw_x + pw_size, pw_y + pw_size], fill=(239, 68, 68, 255))

    # Cruceta / D-Pad circular en el tercio superior
    dpad_size = size * 0.28
    dpad_x = (size - dpad_size) / 2
    dpad_y = ry + size * 0.16
    draw.ellipse(
        [dpad_x, dpad_y, dpad_x + dpad_size, dpad_y + dpad_size],
        fill=(244, 246, 248, 255),
        outline=(210, 215, 222, 255),
        width=int(size * 0.006)
    )

    # Botón OK central del D-Pad
    ok_size = dpad_size * 0.42
    ok_x = (size - ok_size) / 2
    ok_y = dpad_y + (dpad_size - ok_size) / 2
    draw.ellipse(
        [ok_x, ok_y, ok_x + ok_size, ok_y + ok_size],
        fill=(255, 255, 255, 255),
        outline=(190, 196, 205, 255),
        width=int(size * 0.006)
    )

    # Flechas del D-Pad (pequeños puntos elegantes en las 4 direcciones)
    dot_r = size * 0.012
    cx = size / 2
    cy = dpad_y + dpad_size / 2
    dist = dpad_size * 0.34
    for dx, dy in [(0, -dist), (0, dist), (-dist, 0), (dist, 0)]:
        draw.ellipse([cx + dx - dot_r, cy + dy - dot_r, cx + dx + dot_r, cy + dy + dot_r], fill=(120, 130, 145, 255))

    # Botones inferiores (dos columnas suaves de píldoras)
    btn_w = size * 0.13
    btn_h = size * 0.05
    btn_y1 = ry + size * 0.52
    btn_y2 = ry + size * 0.61
    btn_y3 = ry + size * 0.70

    for by in [btn_y1, btn_y2, btn_y3]:
        for bx in [rx + size * 0.065, rx + rw - btn_w - size * 0.065]:
            draw.rounded_rectangle(
                [bx, by, bx + btn_w, by + btn_h],
                radius=int(btn_h / 2),
                fill=(240, 243, 246, 255),
                outline=(220, 225, 232, 255),
                width=int(size * 0.004)
            )

    return img.convert("RGB")

base_img = create_base_icon(1024)

icon_specs = [
    {"idiom": "iphone", "size": "20x20", "scale": "2x", "pixels": 40},
    {"idiom": "iphone", "size": "20x20", "scale": "3x", "pixels": 60},
    {"idiom": "iphone", "size": "29x29", "scale": "2x", "pixels": 58},
    {"idiom": "iphone", "size": "29x29", "scale": "3x", "pixels": 87},
    {"idiom": "iphone", "size": "40x40", "scale": "2x", "pixels": 80},
    {"idiom": "iphone", "size": "40x40", "scale": "3x", "pixels": 120},
    {"idiom": "iphone", "size": "60x60", "scale": "2x", "pixels": 120},
    {"idiom": "iphone", "size": "60x60", "scale": "3x", "pixels": 180},
    {"idiom": "ios-marketing", "size": "1024x1024", "scale": "1x", "pixels": 1024}
]

images_json = []

for spec in icon_specs:
    filename = f"icon_{spec['pixels']}x{spec['pixels']}.png"
    filepath = os.path.join(output_dir, filename)
    resized = base_img.resize((spec['pixels'], spec['pixels']), Image.Resampling.LANCZOS)
    resized.save(filepath, "PNG")
    
    images_json.append({
        "size": spec["size"],
        "idiom": spec["idiom"],
        "filename": filename,
        "scale": spec["scale"]
    })

contents = {
    "images": images_json,
    "info": {
        "version": 1,
        "author": "xcode"
    }
}

with open(os.path.join(output_dir, "Contents.json"), "w") as f:
    json.dump(contents, f, indent=2)

print("AppIcon generated successfully in:", output_dir)
