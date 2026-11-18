export function getAuthIdentifierFieldConfig(register) {
  
  if (register) {
    
    return {
      
      label: 'رقم الهاتف',
      
      type: 'tel',
      
      inputMode: 'tel',
      
      autoComplete: 'tel',
      
      placeholder: '07XXXXXXXXX',
      
    };
    
  }
  

  
  return {
    
    label: 'رقم الهاتف أو البريد الإلكتروني',
    
    type: 'text',
    
    inputMode: 'email',
    
    autoComplete: 'username',
    
    placeholder: '07XXXXXXXXX / name@example.com',
    
  };
  
}



















