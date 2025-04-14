import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="app-page"
export default class extends Controller {

  static values = {
    appPage: String
  }

  connect() {
    this.dispatch("newPageLoad")
    // if returning to welcome page from auth, check if should redirect to a requested page
    if (this.refreshRequired()) {
      // alert("refreshRequired is true")
      this.refreshFrame()
    }
  }

  refreshRequired() {
    // alert('checking if redirect needed')
    // alert(this.getCookie("from_knock"))
    // alert(this.getCookie("return_to"))
    const frameElement = window.document.getElementById('app_window')
    const src = frameElement.getAttribute("src")
    if (!src.includes("knock") && this.getCookie("from_knock") === "true" && this.getCookie("return_to") !== "") {
      // alert('yes - redirect needed')
      return true
    } else {
      // alert('no - redirect not needed')
      return false
    }
  }

  refreshFrame() {
    // alert("in refreshFrame")
    const frameElement = window.document.getElementById('app_window')
    console.log(frameElement) 
    // alert(this.getCookie("return_to"))
    const return_to = "/" + this.getCookie("return_to")
    // alert(return_to)
    frameElement.attributeChangedCallback("src", null, return_to)
    const src = frameElement.getAttribute("src")
    if (src) {
      frameElement.setAttribute("src", return_to)
      // setTimeout(() => {
      //   frameElement.setAttribute("src", return_to)
      // }, 100)
    }
    window.document.cookie = "from_knock=; expires=Thu, 01 Jan 1970 00:00:00 UTC; path=/"
    window.document.cookie = "return_to=; expires=Thu, 01 Jan 1970 00:00:00 UTC; path=/"
  }

  setCookie(cname, cvalue, exdays) {
    const d = new Date();
    d.setTime(d.getTime() + (exdays * 24 * 60 * 60 * 1000));
    let expires = "expires="+d.toUTCString();
    document.cookie = cname + "=" + cvalue + ";" + expires + ";path=/";
  }
  
  getCookie(cname) {
    let name = cname + "=";
    let ca = document.cookie.split(';');
    for(let i = 0; i < ca.length; i++) {
      let c = ca[i];
      while (c.charAt(0) == ' ') {
        c = c.substring(1);
      }
      if (c.indexOf(name) == 0) {
        return c.substring(name.length, c.length);
      }
    }
    return "";
  }

}
