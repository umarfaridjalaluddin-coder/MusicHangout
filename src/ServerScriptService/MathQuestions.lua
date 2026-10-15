-- MathQuestions (PERMANENT)
-- Question bank for the Math Quiz. Kept on the server so the answers are
-- never sent to players' devices. Covers Malaysian primary Darjah 5-6 and
-- secondary Tingkatan 1-3 mathematics topics, selected by Level. Each quiz
-- draws 10 questions at random from the chosen level only.
-- To add a question: copy an entry, put the correct answer FIRST in Choices
-- (the game shuffles the choices before showing them), and keep four choices.

return {
	-- ============================================================
	-- Darjah 5
	-- ============================================================
	{ Level = "Darjah 5", Topic = "Whole numbers", Question = "What is the value of the digit 7 in 472 318?", Choices = { "70 000", "7 000", "700 000", "700" } },
	{ Level = "Darjah 5", Topic = "Whole numbers", Question = "Round 368 459 to the nearest ten thousand.", Choices = { "370 000", "360 000", "368 000", "400 000" } },
	{ Level = "Darjah 5", Topic = "Addition", Question = "245 613 + 128 479 = ?", Choices = { "374 092", "373 092", "374 082", "364 092" } },
	{ Level = "Darjah 5", Topic = "Subtraction", Question = "600 000 − 247 385 = ?", Choices = { "352 615", "353 615", "352 625", "362 615" } },
	{ Level = "Darjah 5", Topic = "Multiplication", Question = "4 215 × 24 = ?", Choices = { "101 160", "100 160", "101 060", "111 160" } },
	{ Level = "Darjah 5", Topic = "Division", Question = "86 400 ÷ 32 = ?", Choices = { "2 700", "270", "2 070", "2 800" } },
	{ Level = "Darjah 5", Topic = "Prime numbers", Question = "Which of these is a prime number?", Choices = { "29", "21", "27", "33" } },
	{ Level = "Darjah 5", Topic = "Fractions", Question = "2/3 + 1/4 = ?", Choices = { "11/12", "3/7", "3/12", "5/6" } },
	{ Level = "Darjah 5", Topic = "Fractions", Question = "3 1/2 − 1 3/4 = ?", Choices = { "1 3/4", "2 1/4", "1 1/4", "2 3/4" } },
	{ Level = "Darjah 5", Topic = "Fractions", Question = "3/5 of 250 = ?", Choices = { "150", "125", "100", "175" } },
	{ Level = "Darjah 5", Topic = "Fractions and decimals", Question = "Which fraction is equal to 0.75?", Choices = { "3/4", "7/5", "3/5", "1/4" } },
	{ Level = "Darjah 5", Topic = "Decimals", Question = "4.385 + 2.67 = ?", Choices = { "7.055", "6.955", "7.045", "7.155" } },
	{ Level = "Darjah 5", Topic = "Decimals", Question = "6.4 × 0.5 = ?", Choices = { "3.2", "32", "0.32", "3.02" } },
	{ Level = "Darjah 5", Topic = "Decimals", Question = "12.6 ÷ 4 = ?", Choices = { "3.15", "3.5", "31.5", "3.05" } },
	{ Level = "Darjah 5", Topic = "Percentages", Question = "Write 3/20 as a percentage.", Choices = { "15%", "6%", "30%", "60%" } },
	{ Level = "Darjah 5", Topic = "Percentages", Question = "25% of RM 480 = ?", Choices = { "RM 120", "RM 100", "RM 125", "RM 96" } },
	{ Level = "Darjah 5", Topic = "Money", Question = "A bag costs RM 80. It is sold at a 15% discount. What is the selling price?", Choices = { "RM 68", "RM 65", "RM 72", "RM 12" } },
	{ Level = "Darjah 5", Topic = "Money", Question = "Ali buys a toy for RM 45 and sells it for RM 60. What is his profit?", Choices = { "RM 15", "RM 5", "RM 25", "RM 105" } },
	{ Level = "Darjah 5", Topic = "Time", Question = "How many minutes are there in 2 3/4 hours?", Choices = { "165 minutes", "150 minutes", "175 minutes", "135 minutes" } },
	{ Level = "Darjah 5", Topic = "Time", Question = "A film starts at 2:45 p.m. and lasts 1 hour 50 minutes. When does it end?", Choices = { "4:35 p.m.", "4:25 p.m.", "4:15 p.m.", "5:35 p.m." } },
	{ Level = "Darjah 5", Topic = "Time", Question = "Write 7:20 p.m. in the 24-hour system.", Choices = { "1920", "0720", "1720", "2120" } },
	{ Level = "Darjah 5", Topic = "Length", Question = "3.6 km = ___ m", Choices = { "3 600 m", "360 m", "36 000 m", "3 060 m" } },
	{ Level = "Darjah 5", Topic = "Mass", Question = "2 kg 450 g + 1 kg 780 g = ?", Choices = { "4 kg 230 g", "3 kg 230 g", "4 kg 130 g", "4 kg 330 g" } },
	{ Level = "Darjah 5", Topic = "Volume of liquid", Question = "4.5 litres = ___ ml", Choices = { "4 500 ml", "450 ml", "45 000 ml", "4 050 ml" } },
	{ Level = "Darjah 5", Topic = "Perimeter", Question = "A rectangle is 12 cm long and 7 cm wide. What is its perimeter?", Choices = { "38 cm", "19 cm", "84 cm", "26 cm" } },
	{ Level = "Darjah 5", Topic = "Area", Question = "What is the area of a square with sides of 9 cm?", Choices = { "81 cm²", "36 cm²", "18 cm²", "72 cm²" } },
	{ Level = "Darjah 5", Topic = "Volume", Question = "What is the volume of a cuboid 5 cm long, 4 cm wide and 3 cm high?", Choices = { "60 cm³", "12 cm³", "47 cm³", "120 cm³" } },
	{ Level = "Darjah 5", Topic = "Angles", Question = "Two angles of a triangle are 65° and 45°. What is the third angle?", Choices = { "70°", "60°", "80°", "110°" } },
	{ Level = "Darjah 5", Topic = "Coordinates", Question = "Point P is 3 units to the right of the origin and 5 units up. What are its coordinates?", Choices = { "(3, 5)", "(5, 3)", "(3, 0)", "(0, 5)" } },
	{ Level = "Darjah 5", Topic = "Ratio", Question = "There are 12 boys and 18 girls. What is the ratio of boys to girls in its simplest form?", Choices = { "2 : 3", "3 : 2", "12 : 18", "6 : 9" } },
	{ Level = "Darjah 5", Topic = "Proportion", Question = "3 pens cost RM 4.50. How much do 7 pens cost?", Choices = { "RM 10.50", "RM 9.00", "RM 12.00", "RM 31.50" } },
	{ Level = "Darjah 5", Topic = "Mean", Question = "What is the mean of 6, 8, 10 and 12?", Choices = { "9", "8", "10", "36" } },
	{ Level = "Darjah 5", Topic = "Mode", Question = "What is the mode of 3, 5, 5, 7, 8, 5, 9?", Choices = { "5", "7", "6", "9" } },
	{ Level = "Darjah 5", Topic = "Range", Question = "What is the range of 14, 9, 21, 17 and 12?", Choices = { "12", "9", "21", "17" } },

	-- ============================================================
	-- Darjah 6
	-- ============================================================
	{ Level = "Darjah 6", Topic = "Whole numbers", Question = "What is 7 503 219 rounded to the nearest hundred thousand?", Choices = { "7 500 000", "7 600 000", "7 000 000", "7 503 000" } },
	{ Level = "Darjah 6", Topic = "Mixed operations", Question = "(250 + 150) ÷ 4 × 2 = ?", Choices = { "200", "100", "400", "50" } },
	{ Level = "Darjah 6", Topic = "Fractions", Question = "2 1/3 × 1 1/2 = ?", Choices = { "3 1/2", "2 1/2", "3 1/6", "2 3/4" } },
	{ Level = "Darjah 6", Topic = "Fractions", Question = "4/5 ÷ 2/3 = ?", Choices = { "1 1/5", "8/15", "2 2/5", "6/10" } },
	{ Level = "Darjah 6", Topic = "Decimals", Question = "0.125 × 1000 = ?", Choices = { "125", "12.5", "1 250", "0.125" } },
	{ Level = "Darjah 6", Topic = "Percentages", Question = "A shop reduces RM 250 by 20% and then adds 6% tax. What is the final price?", Choices = { "RM 212", "RM 200", "RM 220", "RM 265" } },
	{ Level = "Darjah 6", Topic = "Ratio", Question = "A recipe uses flour to sugar in the ratio 5 : 2. If there is 250 g of sugar, how much flour is needed?", Choices = { "625 g", "500 g", "100 g", "750 g" } },
	{ Level = "Darjah 6", Topic = "Speed", Question = "A car travels 180 km in 3 hours. What is its average speed?", Choices = { "60 km/h", "50 km/h", "90 km/h", "40 km/h" } },
	{ Level = "Darjah 6", Topic = "Volume", Question = "What is the volume of a cube with side 6 cm?", Choices = { "216 cm³", "36 cm³", "196 cm³", "116 cm³" } },
	{ Level = "Darjah 6", Topic = "Data handling", Question = "The ages of 5 pupils are 11, 12, 11, 13, 13. What is the median age?", Choices = { "12", "11", "13", "60" } },

	-- ============================================================
	-- Tingkatan 1
	-- ============================================================
	{ Level = "Tingkatan 1", Topic = "Integers", Question = "(-8) + 15 − (-3) = ?", Choices = { "10", "4", "-10", "-4" } },
	{ Level = "Tingkatan 1", Topic = "Integers", Question = "(-6) × (-4) = ?", Choices = { "24", "-24", "10", "-10" } },
	{ Level = "Tingkatan 1", Topic = "Fractions", Question = "1 2/3 + 2 3/4 = ?", Choices = { "4 5/12", "3 5/12", "4 1/12", "3 11/12" } },
	{ Level = "Tingkatan 1", Topic = "Algebraic expressions", Question = "Simplify: 4x + 3y − 2x + y", Choices = { "2x + 4y", "6x + 4y", "2x + 2y", "6x + 2y" } },
	{ Level = "Tingkatan 1", Topic = "Linear equations", Question = "Solve: 3x + 5 = 20", Choices = { "x = 5", "x = 15", "x = 6", "x = 25" } },
	{ Level = "Tingkatan 1", Topic = "Ratio", Question = "Divide RM 360 between Ali and Bob in the ratio 4 : 5.", Choices = { "RM 160 and RM 200", "RM 180 and RM 180", "RM 200 and RM 160", "RM 144 and RM 216" } },
	{ Level = "Tingkatan 1", Topic = "Rate and speed", Question = "A cyclist travels 45 km in 1.5 hours. What is the speed in km/h?", Choices = { "30 km/h", "45 km/h", "67.5 km/h", "15 km/h" } },
	{ Level = "Tingkatan 1", Topic = "Lines and angles", Question = "Two angles on a straight line are 2x and 3x. Find x.", Choices = { "36°", "72°", "108°", "18°" } },
	{ Level = "Tingkatan 1", Topic = "Polygons", Question = "What is the sum of interior angles of a pentagon?", Choices = { "540°", "360°", "720°", "180°" } },
	{ Level = "Tingkatan 1", Topic = "Basic polygons", Question = "How many sides does a hexagon have?", Choices = { "6", "5", "7", "8" } },

	-- ============================================================
	-- Tingkatan 2
	-- ============================================================
	{ Level = "Tingkatan 2", Topic = "Indices", Question = "Simplify: 2³ × 2⁴", Choices = { "2⁷", "2¹²", "4⁷", "2¹" } },
	{ Level = "Tingkatan 2", Topic = "Algebraic formulae", Question = "Make x the subject: y = 3x + 7", Choices = { "x = (y − 7) / 3", "x = (y + 7) / 3", "x = 3y − 7", "x = (y − 3) / 7" } },
	{ Level = "Tingkatan 2", Topic = "Linear equations", Question = "Solve simultaneously: x + y = 10, x − y = 2.", Choices = { "x = 6, y = 4", "x = 4, y = 6", "x = 5, y = 5", "x = 8, y = 2" } },
	{ Level = "Tingkatan 2", Topic = "Polygons", Question = "Each interior angle of a regular polygon is 144°. How many sides does it have?", Choices = { "10", "8", "12", "9" } },
	{ Level = "Tingkatan 2", Topic = "Circles", Question = "Find the circumference of a circle with radius 7 cm. (Use π = 22/7)", Choices = { "44 cm", "22 cm", "154 cm", "49 cm" } },
	{ Level = "Tingkatan 2", Topic = "Circles", Question = "Find the area of a circle with diameter 14 cm. (Use π = 22/7)", Choices = { "154 cm²", "44 cm²", "616 cm²", "88 cm²" } },
	{ Level = "Tingkatan 2", Topic = "Pythagoras' theorem", Question = "A right triangle has legs 6 cm and 8 cm. What is the hypotenuse?", Choices = { "10 cm", "14 cm", "48 cm", "9 cm" } },
	{ Level = "Tingkatan 2", Topic = "Pythagoras' theorem", Question = "A ladder 13 m long leans against a wall with its foot 5 m from the wall. How high up the wall does it reach?", Choices = { "12 m", "18 m", "8 m", "14 m" } },
	{ Level = "Tingkatan 2", Topic = "Statistics", Question = "Find the median of: 4, 8, 6, 2, 10, 12, 3.", Choices = { "6", "7", "8", "5" } },
	{ Level = "Tingkatan 2", Topic = "Graphs of functions", Question = "What is the gradient of the line y = 2x + 3?", Choices = { "2", "3", "-2", "1/2" } },

	-- ============================================================
	-- Tingkatan 3
	-- ============================================================
	{ Level = "Tingkatan 3", Topic = "Expansion and factorisation", Question = "Expand: (x + 3)(x − 2)", Choices = { "x² + x − 6", "x² − x − 6", "x² + 5x − 6", "x² − 5x + 6" } },
	{ Level = "Tingkatan 3", Topic = "Expansion and factorisation", Question = "Factorise: x² − 9", Choices = { "(x+3)(x−3)", "(x−9)(x+1)", "(x+9)(x−1)", "(x−3)²" } },
	{ Level = "Tingkatan 3", Topic = "Quadratic equations", Question = "Solve: x² − 5x + 6 = 0", Choices = { "x = 2 or 3", "x = -2 or -3", "x = 1 or 6", "x = -1 or -6" } },
	{ Level = "Tingkatan 3", Topic = "Algebraic fractions", Question = "Simplify: (3x² ) / (6x)", Choices = { "x/2", "2x", "3x", "x/6" } },
	{ Level = "Tingkatan 3", Topic = "Indices", Question = "Simplify: (x³)² ÷ x²", Choices = { "x⁴", "x⁸", "x⁶", "x²" } },
	{ Level = "Tingkatan 3", Topic = "Trigonometry", Question = "In a right triangle, the opposite side is 3 and the hypotenuse is 5. What is sin θ?", Choices = { "3/5", "4/5", "5/3", "3/4" } },
	{ Level = "Tingkatan 3", Topic = "Trigonometry", Question = "What is tan 45°?", Choices = { "1", "0", "0.5", "undefined" } },
	{ Level = "Tingkatan 3", Topic = "Circles", Question = "An arc subtends 90° at the centre of a circle with radius 14 cm. Find the arc length. (Use π = 22/7)", Choices = { "22 cm", "44 cm", "88 cm", "11 cm" } },
	{ Level = "Tingkatan 3", Topic = "Statistics", Question = "A set of data has mean 20 and 5 values. What is the sum of the values?", Choices = { "100", "20", "25", "4" } },
	{ Level = "Tingkatan 3", Topic = "Bearings", Question = "The bearing of B from A is 070°. What is the bearing of A from B?", Choices = { "250°", "070°", "290°", "180°" } },
}
