import { createApp } from 'vue'
import { createPinia } from 'pinia'
import 'bootstrap/dist/css/bootstrap.min.css'
import 'bootstrap/dist/js/bootstrap.bundle.min.js'
import './fonts.css'
import './style.css'
import App from './App.vue'
import router from './router'
import PtDateInput from './components/PtDateInput.vue'
import IconActionBtn from './components/IconActionBtn.vue'

const app = createApp(App)
app.use(createPinia())
app.use(router)
app.component('PtDateInput',PtDateInput)
// Componente geral de botão-ação (só ícone + popup no hover) reutilizável em toda a app
app.component('IconActionBtn', IconActionBtn)
app.mount('#app')
// Native validation uses the application's language, independently of browser locale.
document.addEventListener('invalid',event=>{
 const field=event.target as HTMLInputElement
 if(!field?.validity||!field.setCustomValidity)return
 field.setCustomValidity('')
 const v=field.validity
 if(v.valueMissing)field.setCustomValidity(field.tagName==='SELECT'?'Seleciona uma opção.':'Preenche este campo.')
 else if(v.typeMismatch)field.setCustomValidity(field.type==='email'?'Introduz um endereço de email válido.':'Introduz um valor válido.')
 else if(v.tooShort)field.setCustomValidity(`Usa pelo menos ${field.minLength} caracteres.`)
 else if(v.rangeUnderflow||v.rangeOverflow||v.stepMismatch)field.setCustomValidity('Introduz um valor dentro dos limites indicados.')
 else if(v.patternMismatch||v.badInput)field.setCustomValidity('Verifica o formato deste campo.')
},true)
document.addEventListener('input',event=>{const field=event.target as HTMLInputElement;field?.setCustomValidity?.('')},true)
document.addEventListener('change',event=>{const field=event.target as HTMLInputElement;field?.setCustomValidity?.('')},true)
