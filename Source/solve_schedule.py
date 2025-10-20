import json
import clingo

DATA_FILE = './Data/daily_01_2024-07-05.json'
SCHEDULER_SOURCE = './Source/schedule_discrete.lp'

# Read model inputs from data file
with open(DATA_FILE) as f:
	data = json.load(f)

# Read base model source
with open(SCHEDULER_SOURCE) as f:
	scheduler_program = f.read()


# Function that prints model output
def print_model(model):
	atoms = model.symbols(shown=True)
	grouped = {}

	# group atoms by predicate name
	for atom in atoms:
		grouped.setdefault(atom.name, []).append(atom)

	# print neatly grouped
	for pred in grouped.keys():
		print(f"% {pred} facts:")
		for fact in sorted(grouped[pred]):
			print(f"  {fact}")
		print()

# Function that prints model summary to track optimization process
def summarize_model(model):
	print(f'Found model #{model.number} with cost {model.cost}; Optimal: {model.optimality_proven}')

# Add in facts from data file
# Note that we just generate ASP code to pass to Clingo. It should be possible to pass symbolic constructs
# instead to prevent the string format/parse pass, but the API for that is a bit finicky. So this works as well.
program_input = ''
for (hour, slot_input) in enumerate(data['schedule_input']):
	# Only one slot per hour for now to reduce complexity
	if hour % 2 == 0:
		continue

	price = round(slot_input['price_buying'] * 1000)
	fact = f'price({(hour // 2) + 1}, {price}).\n'
	program_input += fact

ctl = clingo.Control()

# Construct the model from base program + input
print(f'Constructing model...')
ctl.add("input", [], program_input)
ctl.add("base", [], scheduler_program)

# Ground the model
print(f'Grounding model...')
ctl.ground([("input", []), ("base", [])])

# And solve it
print(f'Starting solve...')
result = ctl.solve(on_model=summarize_model, on_last=print_model)

print(f'Solving result: {result}')
