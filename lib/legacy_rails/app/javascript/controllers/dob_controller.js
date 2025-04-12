import { Controller } from "@hotwired/stimulus"
import { end } from "@popperjs/core";

export default class extends Controller {
  static targets = ["year", "month", "day", "output"];
  lastInputs = {year: '', month: '', day: ''}

  connect() {
    this.disableInputs();
  }

  disableInputs() {
    this.monthTarget.disabled = true;
    this.dayTarget.disabled = true;
  }

  enableMonth() {
    this.monthTarget.disabled = false;
    this.monthTarget.focus();
  }

  enableDay() {
    this.dayTarget.disabled = false;
    this.dayTarget.focus();
  }

  updateAge(event) {
    const year = this.yearTarget.value;
    const month = this.monthTarget.value;
    const day = this.dayTarget.value;

    if (this.shouldEnableMonth(year)) {
      this.setLastInputs();
      this.enableMonth();
    }

    if (this.shouldEnableDay(year, month)) {
      this.setLastInputs();
      this.enableDay();
    }

    if (this.isValidYear(year) && this.isValidDate(year, month, day)) {
      const age = this.currentAge(year, month, day);
      this.outputTarget.textContent = `Current age: ${age}`;
    } else {
      this.outputTarget.textContent = ``;
    }
    this.dispatch("checkForm")
  }

  shouldEnableMonth(year) {
    return this.isValidYear(year) && this.lastInputs.year !== year;
  }

  shouldEnableDay(year, month) {
    return month.length == 2 && this.isValidMonth(month) && this.isValidYear(year) && (this.lastInputs.month !== month || this.lastInputs.year !== year);
  }

  isValidYear(year) {
    const currentYear = new Date().getFullYear();
    return /^[12][0-9]{3}$/.test(year) && year <= currentYear && year >= currentYear - 100;
  }

  isValidMonth(month) {
    return /^0?[1-9]$|^1[0-2]$/.test(month);
  }

  isValidDate(year, month, day){
    const date = new Date(year, month-1, day);
    return year.length == 4 && month.length == 2 && day.length == 2 && date.getFullYear() == year && date.getMonth() == month-1 && date.getDate() == day;
  }

  currentAge(b_year, b_month, b_day) {
    let today = new Date();
    let birthDate = new Date(b_year, b_month-1, b_day);
    let age = today.getFullYear() - birthDate.getFullYear();
    let month = today.getMonth() - birthDate.getMonth();
  
    if (month < 0 || (month === 0 && today.getDate() < birthDate.getDate())) {
      age--;
    }
  
    return age;
  }

  disconnect() {
    this.lastInputs = { year: '', month: '', day: '' }
  }

  setLastInputs() {
    this.lastInputs = {
      year: this.yearTarget.value,
      month: this.monthTarget.value,
      day: this.dayTarget.value
    }
  }
}