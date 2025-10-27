import json
import math
import clingo
from datetime import datetime
from itertools import batched

DATA_FILE = './Data/daily_01_2024-07-05.json'
SCHEDULER_SOURCE = './Source/schedule_discrete.lp'

# This context class allows defining utility methods in Python to be called in the ASP code
class Context:
	def clamp(self, x, lower, upper):
		return min(max(x, lower), upper)
	
	def max(self, a, b):
		return max(a, b)
	
	def min(self, a, b):
		return min(a, b)

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
	print(f'[{datetime.now().strftime("%H:%M:%S")}] Found model #{model.number} with cost {model.cost}; Optimal: {model.optimality_proven}')

# Add in facts from data file
#
# Note that we just generate ASP code to pass to Clingo. It should be possible to pass symbolic constructs
# instead to prevent the string format/parse pass, but the API for that is a bit finicky. So this works as well.
#
# Also note that we are enumerating two slots in a batch. This is to convert from 30 minute slots to 1 hour slots.
# This is to reduce computational complexity.
program_input = ''
batch_count = 4
for (hour, slots) in enumerate(batched(data['schedule_input'], n=batch_count)):
	slot_count = len(slots)

	# Average price between slots, in tenth of cents
	price = sum((slot['price_buying'] * 1000 for slot in slots)) / slot_count

	# Production and consumption are in Wh, not in W. So we use the sum
	production_ac = sum((slot['production_forecast_ac'] for slot in slots))
	production_dc = sum((slot['production_forecast_dc'] for slot in slots))
	consumption = sum((slot['consumption_forecast'] for slot in slots))

	# Output all the atoms as string values in the ASP language
	program_input += f'price({hour + 1}, {round(price)}).\n'
	program_input += f'production({hour + 1}, {round(production_ac + production_dc)}).\n'
	program_input += f'consumption({hour + 1}, {round(consumption)}).\n'

hours = math.ceil(len(data['schedule_input']) / batch_count)

# Put all the constants we want to input in a dict for easy mapping to strings
site = data['site_info']
constants = \
{
	'hours': hours,
	'max_charge_rate': site['max_charge_amount'] * batch_count * 100 / site['battery_capacity'],
	'max_discharge_rate': site['max_discharge_amount'] * batch_count * 100 / site['battery_capacity'],
	'charge_efficiency': site['charge_efficiency_from_ac'] * 100,
	'discharge_efficiency': site['discharge_efficiency_to_ac'] * 100,
}

# Construct command-line parameters as a list of strings
parameters = \
[ 
	# Extra parameters for Clingo
	'--stats', 
	'--parallel-mode', '4',

	# Create -c flag and key=value format for each constant
	*[ s for (key, value) in constants.items() for s in [ '-c', f'{key}={round(value)}' ] ],
]

ctl = clingo.Control(parameters)

print(f'Composite input:')
print(program_input)
print()

# Construct the model from base program + input
print(f'Constructing model...')
ctl.add("input", [], program_input)
ctl.add("base", [], scheduler_program)

# Ground the model
print(f'Grounding model...')
ctl.ground([("input", []), ("base", [ ])], context=Context())

# And solve it
print(f'Starting solve...')
result = ctl.solve(on_model=summarize_model, on_last=print_model)

print(f'Solving result: {result}')
print('Stats:')
print(f'Atoms: {ctl.statistics['problem']['lp']['atoms']}')
print(f'Rules: {ctl.statistics['problem']['lp']['rules']}')
print(f'Choices: {ctl.statistics['solving']['solvers']['choices']}')
print(f'Total time: {ctl.statistics['summary']['times']['total']:.2f}s')
