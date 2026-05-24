# Nutrify – Pengenalan Makanan & Penjadwal Nutrisi Harian

Sumber : https://repository.stikespersadanabire.ac.id/assets/upload/files/docs_1690780458.pdf

Nutrify adalah sistem yang bisa foto makanan, tahu apa isinya, perkirakan porsinya, lalu hitung kalori dan makronya. Setelah itu, angka-angka tadi dibandingkan dengan target kalori harian kamu dan sistemnya langsung bilang apakah makanan itu cocok dengan tujuanmu (turun berat, nambah massa otot, atau maintain).

Ada tiga bagian utama: Flutter (kamera + tampilan aplikasi), FastAPI (backend + orkestrasi ML), dan pipeline ML multi-model (deteksi + klasifikasi + kalkulasi nutrisi).

## Daftar isi

- [Setup project](#setup-project)
- [Struktur project](#struktur-project)
- [Cara kerja pipeline ML](#cara-kerja-pipeline-ml)
- [Dataset](#dataset)
- [Model dan pelatihan](#model-dan-pelatihan)
- [Mekanisme inferensi](#mekanisme-inferensi)
- [Database nutrisi](#database-nutrisi)
- [Estimasi porsi](#estimasi-porsi)
- [Mesin rekomendasi](#mesin-rekomendasi)
- [Endpoint API](#endpoint-api)

---

## Setup project

### Yang dibutuhkan

- Python 3.10+
- Flutter SDK (untuk aplikasi mobile)
- Git

### 1. Clone repository

```bash
git clone https://github.com/leutenantKiya/Nutrify-Food-Recognition-And-Daily-Food-Scheduler.git
cd Nutrify-Food-Recognition-And-Daily-Food-Scheduler
```

### 2. Buat virtual environment dan install dependensi

```bash
python -m venv venv

# Windows
venv\Scripts\activate

# macOS/Linux
source venv/bin/activate

pip install -r requirements.txt
```

### 3. Atur environment variable

Salin `.env.example` ke `.env` dan isi nilainya:

```bash
cp .env.example .env
```

Satu-satunya variabel yang wajib diisi adalah `NUTRIFILE_CHAT_API_KEY` (API key Gemini untuk fitur chat assistant). Pipeline ML-nya sendiri jalan lokal, tidak butuh API key.

### 4. Jalankan server backend

```bash
uvicorn main:app --reload --host 0.0.0.0 --port 8001
```

Dokumentasi API tersedia di `http://localhost:8001/docs`.

### 5. Jalankan aplikasi Flutter

```bash
cd "FrontEnd (Flutter)"
flutter pub get
flutter run
```

Arahkan URL API di aplikasi ke alamat server backend kamu (misal `http://<ip-kamu>:8001`).

### 6. Rebuild Jupyter notebook (kalau perlu)

File `.ipynb` di-generate dari skrip Python. Kalau hilang atau mau di-generate ulang:

```bash
python "Machine Learning/food_detection/_build_notebooks.py"
```

---

## Struktur project

```
Nutrify-Food-Recognition-And-Daily-Food-Scheduler/
|
|-- FrontEnd (Flutter)/          # Aplikasi mobile Flutter (kamera, UI, API call)
|
|-- app/                         # Backend FastAPI
|   |-- core/
|   |   |-- knowledge.py         # Tabel lookup bahan tersembunyi per hidangan
|   |   |-- settings.py          # Konfigurasi app (path, API key, default)
|   |-- models/
|   |   |-- schemas.py           # Skema request/response Pydantic
|   |-- routers/
|   |   |-- chat_router.py       # (dihapus — chat ditangani langsung oleh Flutter)
|   |   |-- meal_router.py       # Endpoint /analyze_meal (router produksi)
|   |-- services/
|       |-- chat_service.py      # (dihapus — tidak dipakai)
|       |-- meal_service.py      # Orkestrasi pipeline ML + penanganan gambar
|
|-- Machine Learning/
|   |-- food_detection/
|       |-- nutrifile/           # Package pipeline ML
|       |   |-- classifier.py    # Loader EfficientNet-B0 dan predict_topk()
|       |   |-- config.py        # Semua hyperparameter dan konfigurasi path
|       |   |-- explain.py       # Generator ringkasan bahasa natural
|       |   |-- nutrition.py     # Database nutrisi per 100g (sumber USDA)
|       |   |-- ontology.py      # Pemetaan nama kelas (Food101, Singular)
|       |   |-- pipeline.py      # Orkestrator inferensi end-to-end
|       |   |-- portion.py       # Estimator area mask -> gram
|       |   |-- recommend.py     # Mesin rekomendasi diet berbasis aturan
|       |-- tests/               # Unit test (pytest)
|       |-- _build_notebooks.py  # Generate .ipynb dari skrip sumber .py
|
|-- results/_output_/
|   |-- weights/                 # Bobot model terlatih (file .pt)
|   |-- dish_cls_dataset/        # Gambar Food101 (101 kelas)
|   |-- ingredient_cls_dataset/  # Gambar Singular Food Items (50 kelas)
|   |-- produce_dataset/         # Data segmentasi PackEat (gambar + label)
|   |-- runs/                    # Log training, kurva, confusion matrix
|
|-- main.py                      # Entry point aplikasi FastAPI
|-- requirements.txt             # Dependensi Python
|-- .env.example                 # Template environment variable
```

---

## Cara kerja pipeline ML

Ketika foto makanan dikirim, pipeline berjalan secara berurutan seperti ini:

```
Foto (gambar RGB)
  |
  v
[1] Detektor YOLOv8-seg "produce" --> mask segmentasi biner (mana yang makanan?)
  |                                   + COCO ensemble untuk pizza/donut/kue/dll.
  v
[2] Untuk setiap area makanan yang terdeteksi:
      Crop ROI dengan polygon mask
        |
        +--> Klasifier bahan EfficientNet-B0 --> top-3 prediksi
        |
        +--> Klasifier hidangan EfficientNet-B0 --> top-3 prediksi
        |
        +--> Label router pilih label terbaik (bahan vs hidangan)
  |
  v
[3] Estimasi porsi: rasio area mask * area piring * densitas makanan = gram
  |
  v
[4] Lookup nutrisi: gram * (kkal per 100g) untuk setiap makro
  |
  v
[5] Agregasi total dari semua item yang terdeteksi
  |
  v
[6] Mesin rekomendasi: bandingkan total dengan target harian, jalankan aturan
  |
  v
[7] Penjelasan makanan dalam bahasa natural
```

---

## Dataset

Pipeline menggunakan tiga dataset publik, masing-masing melatih model yang berbeda:

### 1. Food-101 (klasifikasi hidangan)

- **Sumber**: Dataset Food-101 ETH Zurich
- **Konten**: 101.000 gambar dari 101 kategori hidangan
- **Contoh**: pizza, sushi, ramen, fried_rice, steak, tiramisu, hamburger, pad_thai
- **Split**: train / val / test
- **Tersimpan di**: `results/_output_/dish_cls_dataset/`
- **Melatih**: Klasifier hidangan (EfficientNet-B0)

### 2. Singular Food Items (klasifikasi bahan)

- **Sumber**: Dataset Singular Food Items (Kaggle)
- **Konten**: ~50 kategori bahan mentah individual
- **Contoh**: apel, alpukat, bacon, brokoli, telur, ayam, tahu, nasi, keju, tomat
- **Split**: train / val / test
- **Tersimpan di**: `results/_output_/ingredient_cls_dataset/`
- **Melatih**: Klasifier bahan (EfficientNet-B0)
- **Catatan**: Kelas "noise" (gambar bukan makanan dari dataset asli) dihapus sebelum training. Total akhirnya 50 kelas yang valid.

### 3. PackEat (segmentasi produk)

- **Sumber**: Packed Fruits and Vegetables Recognition Benchmark (Kaggle)
- **Konten**: Gambar makanan dengan anotasi polygon dalam format YOLO
- **Format**: `images/` (JPEG) + `labels/` (file teks dengan koordinat polygon ternormalisasi)
- **Split**: train / val / test
- **Tersimpan di**: `results/_output_/produce_dataset/`
- **Melatih**: Detektor produk (YOLOv8s-seg, segmentasi biner "apakah ini makanan?")

---

## Model dan pelatihan

Tiga model bekerja bersama. Konfigurasi training ada di `nutrifile/config.py`.

| Model | Arsitektur | Tugas | Kelas | Konfigurasi |
|---|---|---|---|---|
| Detektor produk | YOLOv8s-seg | Instance segmentation (biner: makanan vs bukan) | 1 | 40 epoch, imgsz 640, batch 16, patience 8 |
| Klasifier bahan | EfficientNet-B0 | Klasifikasi gambar (bahan mentah) | 50 | 15 epoch, lr 3e-4, imgsz 224, batch 64, mixup 0.1 |
| Klasifier hidangan | EfficientNet-B0 | Klasifikasi gambar (hidangan matang) | 101 | Sama dengan klasifier bahan |

Bobot hasil training disimpan di `results/_output_/weights/`:
- `produce_yolov8s_seg.pt`
- `ingredient_effnetb0.pt` + `ingredient_effnetb0.classes.json`
- `dish_effnetb0.pt` + `dish_effnetb0.classes.json`

Model `yolov8s-seg.pt` pretrained COCO juga dipakai sebagai layer ensemble. Detektor produk dilatih dengan data PackEat yang tidak mencakup kategori seperti pizza atau kue. COCO sudah tahu kategori itu (ID kelas 46-55), jadi pipeline menjalankan kedua detektor dan menggabungkan hasilnya. Kalau deteksi COCO overlap dengan deteksi produk, label COCO yang menang.

---

## Mekanisme inferensi

### Routing label

Setiap area makanan yang terdeteksi di-crop lalu dikirim ke kedua klasifier. Router kemudian memutuskan label mana yang dipakai. Logika keputusannya, berurutan:

1. **Tolak non-makanan**: Kalau kedua klasifier punya kepercayaan top-1 di bawah 0.30, area itu diberi label "unknown" dan dilewati (kemungkinan tangan, piring, atau peralatan makan).

2. **Family guard (override ke bahan)**: Beberapa hidangan punya padanan bahan polosnya. Misalnya, klasifier hidangan mungkin bilang "fried_rice" saat melihat nasi kukus biasa. Kalau klasifier bahan juga mendeteksi "rice" dengan kepercayaan sedang (0.15-0.50), sistem override ke label yang lebih sederhana. Ini mencegah kalori dihitung terlalu tinggi. Pemetaan lengkapnya ada di `pipeline.py` (`DISH_TO_INGREDIENT_FALLBACK`).

3. **Area besar + hidangan yakin**: Kalau area makanan mencakup >= 10% gambar dan kepercayaan klasifier hidangan >= 0.45, pakai label hidangan. Area besar biasanya artinya makanan jadi, bukan bahan tunggal.

4. **Bahan yakin mengalahkan hidangan**: Kalau kepercayaan klasifier bahan >= 0.55 dan lebih tinggi dari kepercayaan hidangan, pakai label bahan.

5. **Hidangan yakin (area kecil)**: Kalau klasifier hidangan memenuhi batas kepercayaannya (0.45), pakai label hidangan.

6. **Fallback**: Klasifier dengan probabilitas top-1 lebih tinggi yang menang.

### Deduplikasi

YOLO kadang menghasilkan deteksi yang tumpang tindih untuk makanan yang sama (misal pizza utuh dan sepotong kecil di dalamnya). Tanpa deduplikasi, total nutrisi bisa terhitung dua kali. Pipeline menjalankan dua tahap deduplikasi:

- **Dedup pra-klasifikasi**: Khusus di antara deteksi produk. Kalau deteksi yang lebih kecil >= 70% berada di dalam yang lebih besar, atau IoU-nya >= 0.60, yang kecil dibuang.
- **Supresi COCO**: Kalau deteksi produk overlap signifikan dengan deteksi COCO (containment >= 0.50 atau IoU >= 0.40), deteksi produk dibuang karena label COCO lebih spesifik.

---

## Database nutrisi

Database nutrisi ada di `nutrifile/nutrition.py`. Semua nilai per 100g porsi yang bisa dimakan.

### Sumber data

- **Bahan**: Bersumber dari USDA FoodData Central. Dibulatkan ke integer untuk kkal/natrium, satu desimal untuk makro. Tag kepercayaan: "high".
- **Hidangan**: Dirata-rata dari kartu resep referensi umum. Tag kepercayaan: "med".
- **Fallback**: Kalau makanan yang terdeteksi tidak ada di database, pakai entri beban moderat generik (200 kkal, 20g karbohidrat, 8g protein, 8g lemak per 100g). Tag kepercayaan: "low".

### Field per entri

Setiap item makanan menyimpan: `kcal`, `carbs`, `protein`, `fat`, `sugar`, `sodium`, `fiber`, dan `density_g_per_cm2` (dipakai oleh estimator porsi).

Database mencakup 50 kunci bahan dan 101+ kunci hidangan. Cakupannya bisa dicek secara terprogram dengan `nutrition.coverage_report()`.

### Database bahan tersembunyi

File `app/core/knowledge.py` berisi kamus yang memetakan nama hidangan ke "bahan tersembunyi" — hal-hal yang tidak terlihat di foto tapi pasti ada di makanan itu. Contohnya:

- `fried_rice` → minyak, bawang putih, kecap asin, garam, lada
- `sushi` → cuka beras, gula, kecap asin, wasabi, nori
- `tiramisu` → mascarpone, espresso, bubuk kakao, gula, telur

Pemetaan ini mencakup 70+ hidangan dari berbagai kategori (nasi, pasta, sandwich, sup, salad, dessert, dll.). API mengembalikannya sebagai `estimated_hidden_ingredients` dalam respons, supaya pengguna dapat gambaran yang lebih realistis tentang apa yang mereka makan.

---

## Estimasi porsi

Memperkirakan seberapa banyak makanan di piring tanpa timbangan itu susah. Sistem menggunakan pendekatan berbasis geometri:

### Cara kerjanya

1. **Asumsikan foto dari atas di permukaan makan standar.** Kebanyakan foto makanan memang diambil dari sudut itu.
2. **Ambil area polygon mask** dari segmentasi YOLOv8. Ini adalah fraksi (0 sampai 1) dari total area gambar.
3. **Kalikan dengan area piring referensi.** Asumsi default: piring makan 25 cm mengisi sekitar 70% frame. Itu memberi total area frame ~701 cm2.
4. **Kalikan dengan densitas spesifik makanan** (`density_g_per_cm2` dari database nutrisi). Makanan berbeda punya berat yang berbeda per satuan area permukaan yang terlihat. Steak (0.60 g/cm2) lebih padat dari selada (0.20 g/cm2).

### Rumusnya

```
frame_area_cm2 = pi * (25/2)^2 / 0.70  ≈ 701 cm2
food_area_cm2  = mask_area_ratio * frame_area_cm2
grams          = food_area_cm2 * density_g_per_cm2
```

### Lalu untuk nutrisi

```
kcal    = (entry.kcal    / 100) * grams
protein = (entry.protein / 100) * grams
carbs   = (entry.carbs   / 100) * grams
fat     = (entry.fat     / 100) * grams
...dan seterusnya untuk sugar, sodium, fiber
```

Sistem juga mendukung override objek referensi. Kalau kamu meletakkan objek yang diketahui ukurannya (seperti koin) di frame, pipeline bisa menghitung balik area frame sebenarnya dari ukuran fisik objek dan rasio masknya.

---

## Mesin rekomendasi

Setelah total nutrisi makanan dihitung, sistem membandingkannya dengan target per-makan yang diturunkan dari anggaran kalori harian pengguna. Aturan-aturannya ada di `nutrifile/recommend.py`.

### Perhitungan target per-makan

Anggaran kalori harian dibagi ke semua makan (default: 3 makan/hari), lalu dipecah berdasarkan rasio makronutrien:

| Makro | Bagian dari energi | Konversi | Rumus per-makan |
|---|---|---|---|
| Karbohidrat | 50% | 4 kkal/g | `(daily_kcal / meals) * 0.50 / 4` |
| Protein | 20% | 4 kkal/g | `(daily_kcal / meals) * 0.20 / 4` |
| Lemak | 30% | 9 kkal/g | `(daily_kcal / meals) * 0.30 / 9` |
| Gula | Panduan WHO | - | 25g per makan (batas 75g/hari) |
| Natrium | Panduan AHA | - | 766mg per makan (batas 2300mg/hari) |
| Serat | Panduan umum | - | ~9.3g per makan (total 28g/hari) |

### Aturan-aturan

Setiap aturan berjalan independen dan mengembalikan saran terstruktur dengan kode, tingkat keparahan (info / warning / alert), pesan, dan angka yang memicunya.

| Aturan | Aktif saat | Tahu tujuan? |
|---|---|---|
| `CAL_OVER_WEIGHT_LOSS` | Kkal makan > 110% target | Hanya turun berat |
| `CAL_UNDER_MUSCLE` | Kkal makan < 90% target | Hanya nambah otot |
| `CAL_OFF_MAINTENANCE` | Kkal makan > 120% di atas/bawah target | Hanya maintenance |
| `LOW_PROTEIN` | Protein < 70% target | Ya (peringatan ekstra untuk nambah otot) |
| `HIGH_SUGAR` | Gula > 120% panduan per-makan | Tidak |
| `HIGH_SODIUM` | Natrium > 120% panduan per-makan | Tidak |
| `HIGH_FAT` | Lemak > 150% target | Tidak |
| `LOW_FIBER` | Serat < 50% target, dan makan > 200 kkal | Tidak |
| `CARB_DOMINANT` | Karbohidrat menyuplai > 65% energi makan | Tidak |
| `FAT_DOMINANT` | Lemak menyuplai > 45% energi makan | Tidak |
| `LOW_PROTEIN_PCT` | Protein menyuplai < 10% energi, dan makan > 200 kkal | Tidak |

---

## Endpoint API

### POST /analyze_meal

Menerima multipart form data (file gambar + data biometrik). Gambar disimpan ke `temp_image_POST/`, diproses melalui pipeline ML, dan hasil anotasi disimpan ke `uploads/`.

Field form: `img` atau `image` (file), `goal`, `weight`, `height`, `age`, `gender`, `activity_level`, `daily_target`

### POST /analyze_meal/blob

Sama seperti di atas, tapi menerima JSON body dengan string gambar ter-encode base64 instead of file upload.


### GET /

Health check. Mengembalikan `{"status": "ok"}`.

Semua endpoint juga tersedia dengan prefix `/api/v1/`.
