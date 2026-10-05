-- MalayQuestions (PERMANENT)
-- Bank soalan untuk Kuiz Bahasa Melayu. Question bank for the Bahasa Melayu
-- quiz, kept on the server so the answers are never sent to players' devices.
-- Aimed at Malaysian primary Year 5 (Tahun 5) Bahasa Melayu: tatabahasa,
-- kosa kata, simpulan bahasa and peribahasa. Each quiz draws 10 at random.
-- To add a question: copy an entry, put the correct answer FIRST in Choices
-- (the game shuffles the choices before showing them), and keep four choices.

return {
	-- Golongan kata
	{ Topic = "Kata nama am", Question = "Antara berikut, yang manakah kata nama am?", Choices = { "sekolah", "Kuala Lumpur", "Proton", "Sungai Pahang" } },
	{ Topic = "Kata nama khas", Question = "Antara berikut, yang manakah kata nama khas?", Choices = { "Gunung Kinabalu", "gunung", "sungai", "bandar" } },
	{ Topic = "Kata kerja", Question = "Adik sedang ___ buku cerita di perpustakaan.", Choices = { "membaca", "bacaan", "pembaca", "pembacaan" } },
	{ Topic = "Kata adjektif", Question = "Antara berikut, yang manakah kata adjektif?", Choices = { "cantik", "berlari", "meja", "dan" } },
	{ Topic = "Kata bilangan", Question = "___ murid hadir ke sekolah hari ini; tiada seorang pun yang tidak hadir.", Choices = { "Semua", "Beberapa", "Separuh", "Sedikit" } },

	-- Kata ganti nama diri
	{ Topic = "Kata ganti nama diri", Question = "Kata ganti nama diri yang sesuai untuk raja atau sultan ialah ___.", Choices = { "baginda", "beliau", "dia", "mereka" } },
	{ Topic = "Kata ganti nama diri", Question = "Kata ganti nama diri \"beliau\" digunakan untuk ___.", Choices = { "orang yang dihormati", "kanak-kanak", "haiwan", "benda" } },
	{ Topic = "Kata ganti nama diri", Question = "Yang manakah kata ganti nama diri pertama?", Choices = { "saya", "dia", "mereka", "awak" } },

	-- Penjodoh bilangan
	{ Topic = "Penjodoh bilangan", Question = "Ayah membeli ___ kereta baharu.", Choices = { "sebuah", "seekor", "sebatang", "sehelai" } },
	{ Topic = "Penjodoh bilangan", Question = "Ibu membeli tiga ___ ikan di pasar.", Choices = { "ekor", "buah", "biji", "helai" } },
	{ Topic = "Penjodoh bilangan", Question = "Kakak memakai ___ baju kurung berwarna biru.", Choices = { "sehelai", "sebuah", "sebiji", "sebatang" } },
	{ Topic = "Penjodoh bilangan", Question = "Abang menebang ___ pokok kelapa.", Choices = { "sebatang", "sehelai", "seekor", "sebiji" } },
	{ Topic = "Penjodoh bilangan", Question = "Emak membeli ___ telur ayam.", Choices = { "sepuluh biji", "sepuluh ekor", "sepuluh helai", "sepuluh batang" } },

	-- Kata sendi nama
	{ Topic = "Kata sendi nama", Question = "Buku itu ada ___ atas meja.", Choices = { "di", "ke", "dari", "pada" } },
	{ Topic = "Kata sendi nama", Question = "Mereka akan bertolak ___ Pulau Pinang pada pagi esok.", Choices = { "ke", "di", "pada", "daripada" } },
	{ Topic = "Kata sendi nama", Question = "Hadiah ini saya terima ___ ibu saya.", Choices = { "daripada", "dari", "kepada", "pada" } },
	{ Topic = "Kata sendi nama", Question = "Cikgu memberikan buku latihan ___ murid-murid.", Choices = { "kepada", "ke", "daripada", "dari" } },

	-- Kata hubung
	{ Topic = "Kata hubung", Question = "Ali tidak hadir ke sekolah ___ dia demam.", Choices = { "kerana", "tetapi", "lalu", "atau" } },
	{ Topic = "Kata hubung", Question = "Kamu mahu minum teh ___ kopi?", Choices = { "atau", "kerana", "supaya", "walaupun" } },
	{ Topic = "Kata hubung", Question = "Dia rajin belajar ___ lulus dalam peperiksaan.", Choices = { "supaya", "tetapi", "atau", "walaupun" } },
	{ Topic = "Kata hubung", Question = "___ hujan lebat, mereka tetap pergi ke sekolah.", Choices = { "Walaupun", "Kerana", "Supaya", "Lalu" } },

	-- Imbuhan
	{ Topic = "Imbuhan", Question = "Ibu sedang ___ sayur di dapur. (potong)", Choices = { "memotong", "mempotong", "mengpotong", "menpotong" } },
	{ Topic = "Imbuhan", Question = "Kakak ___ sampah di halaman rumah. (sapu)", Choices = { "menyapu", "mensapu", "mengsapu", "mesapu" } },
	{ Topic = "Imbuhan", Question = "Ayah ___ kereta ke pejabat. (pandu)", Choices = { "memandu", "mempandu", "menpandu", "mengpandu" } },
	{ Topic = "Imbuhan", Question = "Bola itu ___ oleh Ahmad. (tendang)", Choices = { "ditendang", "menendang", "tendangan", "penendang" } },

	-- Sinonim dan antonim
	{ Topic = "Sinonim", Question = "Perkataan seerti bagi \"cantik\" ialah ___.", Choices = { "indah", "hodoh", "besar", "laju" } },
	{ Topic = "Sinonim", Question = "Perkataan seerti bagi \"gembira\" ialah ___.", Choices = { "riang", "sedih", "marah", "takut" } },
	{ Topic = "Antonim", Question = "Perkataan berlawan bagi \"rajin\" ialah ___.", Choices = { "malas", "pandai", "tekun", "cergas" } },
	{ Topic = "Antonim", Question = "Perkataan berlawan bagi \"tinggi\" ialah ___.", Choices = { "rendah", "besar", "panjang", "lebar" } },

	-- Simpulan bahasa dan peribahasa
	{ Topic = "Simpulan bahasa", Question = "Simpulan bahasa \"ringan tulang\" bermaksud ___.", Choices = { "rajin bekerja", "malas bekerja", "kurus", "suka bercakap" } },
	{ Topic = "Simpulan bahasa", Question = "Simpulan bahasa \"buah tangan\" bermaksud ___.", Choices = { "hadiah atau ole-ole", "buah-buahan", "tangan yang sakit", "sarung tangan" } },
	{ Topic = "Simpulan bahasa", Question = "Simpulan bahasa \"anak emas\" bermaksud ___.", Choices = { "anak yang paling disayangi", "anak orang kaya", "anak yang nakal", "barang kemas" } },
	{ Topic = "Simpulan bahasa", Question = "Simpulan bahasa \"kaki bangku\" bermaksud ___.", Choices = { "tidak pandai bermain bola", "pandai bermain bola", "suka duduk", "tukang kayu" } },
	{ Topic = "Peribahasa", Question = "Peribahasa \"bagai aur dengan tebing\" bermaksud ___.", Choices = { "saling membantu", "selalu bergaduh", "sangat miskin", "sangat sombong" } },

	-- Kata tanya, kata seru, kata ganda, tanda baca, ayat
	{ Topic = "Kata tanya", Question = "___ nama guru kelas kamu?", Choices = { "Siapakah", "Bilakah", "Di manakah", "Berapakah" } },
	{ Topic = "Kata tanya", Question = "___ kamu akan pulang ke kampung?", Choices = { "Bilakah", "Siapakah", "Manakah", "Berapakah" } },
	{ Topic = "Kata seru", Question = "___, cantiknya pemandangan di sini!", Choices = { "Wah", "Aduh", "Cis", "Wahai" } },
	{ Topic = "Kata ganda", Question = "Kata ganda bagi \"buku\" yang bermaksud banyak buku ialah ___.", Choices = { "buku-buku", "bukuan", "berbuku", "pembuku" } },
	{ Topic = "Tanda baca", Question = "Tanda baca yang sesuai di hujung ayat tanya ialah ___.", Choices = { "tanda soal (?)", "tanda seru (!)", "noktah (.)", "koma (,)" } },
	{ Topic = "Membina ayat", Question = "Susun perkataan ini menjadi ayat yang betul: ke / pergi / Ali / sekolah", Choices = { "Ali pergi ke sekolah.", "Ali ke pergi sekolah.", "Sekolah pergi ke Ali.", "Pergi Ali sekolah ke." } },
}
