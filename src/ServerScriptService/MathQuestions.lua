-- MathQuestions (PERMANENT)
-- Question bank for the Math Quiz. Kept on the server so the answers are
-- never sent to players' devices. Aimed at Malaysian primary Year 5 (Tahun 5)
-- mathematics topics. Each quiz draws 10 of these at random.
-- To add a question: copy an entry, put the correct answer FIRST in Choices
-- (the game shuffles the choices before showing them), and keep four choices.

return {
	-- Whole numbers and operations
	{ Topic = "Whole numbers", Question = "What is the value of the digit 7 in 472 318?", Choices = { "70 000", "7 000", "700 000", "700" } },
	{ Topic = "Whole numbers", Question = "Round 368 459 to the nearest ten thousand.", Choices = { "370 000", "360 000", "368 000", "400 000" } },
	{ Topic = "Addition", Question = "245 613 + 128 479 = ?", Choices = { "374 092", "373 092", "374 082", "364 092" } },
	{ Topic = "Subtraction", Question = "600 000 − 247 385 = ?", Choices = { "352 615", "353 615", "352 625", "362 615" } },
	{ Topic = "Multiplication", Question = "4 215 × 24 = ?", Choices = { "101 160", "100 160", "101 060", "111 160" } },
	{ Topic = "Division", Question = "86 400 ÷ 32 = ?", Choices = { "2 700", "270", "2 070", "2 800" } },
	{ Topic = "Prime numbers", Question = "Which of these is a prime number?", Choices = { "29", "21", "27", "33" } },

	-- Fractions, decimals and percentages
	{ Topic = "Fractions", Question = "2/3 + 1/4 = ?", Choices = { "11/12", "3/7", "3/12", "5/6" } },
	{ Topic = "Fractions", Question = "3 1/2 − 1 3/4 = ?", Choices = { "1 3/4", "2 1/4", "1 1/4", "2 3/4" } },
	{ Topic = "Fractions", Question = "3/5 of 250 = ?", Choices = { "150", "125", "100", "175" } },
	{ Topic = "Fractions and decimals", Question = "Which fraction is equal to 0.75?", Choices = { "3/4", "7/5", "3/5", "1/4" } },
	{ Topic = "Decimals", Question = "4.385 + 2.67 = ?", Choices = { "7.055", "6.955", "7.045", "7.155" } },
	{ Topic = "Decimals", Question = "6.4 × 0.5 = ?", Choices = { "3.2", "32", "0.32", "3.02" } },
	{ Topic = "Decimals", Question = "12.6 ÷ 4 = ?", Choices = { "3.15", "3.5", "31.5", "3.05" } },
	{ Topic = "Percentages", Question = "Write 3/20 as a percentage.", Choices = { "15%", "6%", "30%", "60%" } },
	{ Topic = "Percentages", Question = "25% of RM 480 = ?", Choices = { "RM 120", "RM 100", "RM 125", "RM 96" } },

	-- Money
	{ Topic = "Money", Question = "A bag costs RM 80. It is sold at a 15% discount. What is the selling price?", Choices = { "RM 68", "RM 65", "RM 72", "RM 12" } },
	{ Topic = "Money", Question = "Ali buys a toy for RM 45 and sells it for RM 60. What is his profit?", Choices = { "RM 15", "RM 5", "RM 25", "RM 105" } },

	-- Time
	{ Topic = "Time", Question = "How many minutes are there in 2 3/4 hours?", Choices = { "165 minutes", "150 minutes", "175 minutes", "135 minutes" } },
	{ Topic = "Time", Question = "A film starts at 2:45 p.m. and lasts 1 hour 50 minutes. When does it end?", Choices = { "4:35 p.m.", "4:25 p.m.", "4:15 p.m.", "5:35 p.m." } },
	{ Topic = "Time", Question = "Write 7:20 p.m. in the 24-hour system.", Choices = { "1920", "0720", "1720", "2120" } },

	-- Measurement
	{ Topic = "Length", Question = "3.6 km = ___ m", Choices = { "3 600 m", "360 m", "36 000 m", "3 060 m" } },
	{ Topic = "Mass", Question = "2 kg 450 g + 1 kg 780 g = ?", Choices = { "4 kg 230 g", "3 kg 230 g", "4 kg 130 g", "4 kg 330 g" } },
	{ Topic = "Volume of liquid", Question = "4.5 litres = ___ ml", Choices = { "4 500 ml", "450 ml", "45 000 ml", "4 050 ml" } },

	-- Shape and space
	{ Topic = "Perimeter", Question = "A rectangle is 12 cm long and 7 cm wide. What is its perimeter?", Choices = { "38 cm", "19 cm", "84 cm", "26 cm" } },
	{ Topic = "Area", Question = "What is the area of a square with sides of 9 cm?", Choices = { "81 cm²", "36 cm²", "18 cm²", "72 cm²" } },
	{ Topic = "Volume", Question = "What is the volume of a cuboid 5 cm long, 4 cm wide and 3 cm high?", Choices = { "60 cm³", "12 cm³", "47 cm³", "120 cm³" } },
	{ Topic = "Angles", Question = "Two angles of a triangle are 65° and 45°. What is the third angle?", Choices = { "70°", "60°", "80°", "110°" } },

	-- Coordinates, ratio and proportion
	{ Topic = "Coordinates", Question = "Point P is 3 units to the right of the origin and 5 units up. What are its coordinates?", Choices = { "(3, 5)", "(5, 3)", "(3, 0)", "(0, 5)" } },
	{ Topic = "Ratio", Question = "There are 12 boys and 18 girls. What is the ratio of boys to girls in its simplest form?", Choices = { "2 : 3", "3 : 2", "12 : 18", "6 : 9" } },
	{ Topic = "Proportion", Question = "3 pens cost RM 4.50. How much do 7 pens cost?", Choices = { "RM 10.50", "RM 9.00", "RM 12.00", "RM 31.50" } },

	-- Data handling
	{ Topic = "Mean", Question = "What is the mean of 6, 8, 10 and 12?", Choices = { "9", "8", "10", "36" } },
	{ Topic = "Mode", Question = "What is the mode of 3, 5, 5, 7, 8, 5, 9?", Choices = { "5", "7", "6", "9" } },
	{ Topic = "Range", Question = "What is the range of 14, 9, 21, 17 and 12?", Choices = { "12", "9", "21", "17" } },
}
