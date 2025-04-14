import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="sign-up"
export default class extends Controller {

  static targets = ["s", "y", "m", "d", "z", "zConfirm", "submitButton"];


  connect() {
    this.checkFormValidity()
  }

  checkFormValidity() {
    if (this.isValidDate(this.yTarget.value, this.mTarget.value, this.dTarget.value) && (this.yTarget.value >= (new Date().getFullYear()) - 100) &&
        this.sTarget.value != 0 && 
        (this.zTarget.value.length == 0 || (this.zTarget.value.length == 5 && this.zConfirmTarget.innerHTML != '')) &&
        true) {
      this.enableSubmit()
    } else {
      this.disableSubmit()
    }
  }

  enableSubmit() {
    this.submitButtonTarget.disabled = false;
  }

  disableSubmit() {
    this.submitButtonTarget.disabled = true;
  }

  isValidDate(year, month, day){
    const date = new Date(year, month-1, day);
    return year.length == 4 && month.length == 2 && day.length == 2 && date.getFullYear() == year && date.getMonth() == month-1 && date.getDate() == day;
  }

}
