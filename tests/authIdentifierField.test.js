import test from 'node:test';

import assert from 'node:assert/strict';

import { getAuthIdentifierFieldConfig } from '../src/features/authIdentifierField.js';



test('login identifier accepts phone or email and does not force a numeric keyboard', () => {
  
  assert.deepEqual(getAuthIdentifierFieldConfig(false), {
    
    label: 'رقم الهاتف أو البريد الإلكتروني',
    
    type: 'text',
    
    inputMode: 'email',
    
    autoComplete: 'username',
    
    placeholder: '07XXXXXXXXX / name@example.com',
    
  });
  
});



test('registration keeps the phone keyboard and phone-only hint', () => {
  
  assert.deepEqual(getAuthIdentifierFieldConfig(true), {
    
    label: 'رقم الهاتف',
    
    type: 'tel',
    
    inputMode: 'tel',
    
    autoComplete: 'tel',
    
    placeholder: '07XXXXXXXXX',
    
  });
  
});

















