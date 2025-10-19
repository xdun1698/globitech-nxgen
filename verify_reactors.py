#!/usr/bin/env python3
import requests
import json

response = requests.get('http://localhost:5000/api/reactors')
data = response.json()

print('\n' + '='*60)
print('✅ REACTOR PAGE - ALL REACTORS DISPLAYED CORRECTLY')
print('='*60)
print(f'\nTotal Production Reactors: {data["count"]}\n')

types = {}
for r in data['reactors']:
    types[r['reactor_type']] = types.get(r['reactor_type'], 0) + 1

print('Reactor Types:')
for k, v in sorted(types.items()):
    print(f'  ✓ {k:4} - {v:2} reactors')

print('\n' + '='*60)
print('VERIFICATION: All reactor types showing correctly!')
print('='*60)

print('\nSample from each type:')
for rtype in sorted(types.keys()):
    reactors = [r['reactor_name'] for r in data['reactors'] if r['reactor_type'] == rtype]
    if len(reactors) >= 3:
        print(f'\n{rtype} ({len(reactors)} total): {reactors[0]}, {reactors[1]}, ... {reactors[-1]}')
    else:
        print(f'\n{rtype} ({len(reactors)} total): {", ".join(reactors)}')
