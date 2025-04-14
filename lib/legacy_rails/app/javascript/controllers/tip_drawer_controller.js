import { Controller } from "@hotwired/stimulus"
import { post, get } from '@rails/request.js'

export default class extends Controller {

  static values = {
    offer: String
  }

  static targets = [ "drawer"]

  connect() {
    console.log('drawer reporting for duty')
  }


  toggleDrawer() {
    const drawer = document.querySelector('.tip-drawer');
    const drawerHeight = drawer.offsetHeight;
    const viewportHeight = window.innerHeight;
    console.log('toggle drawer')
    document.body.classList.toggle('tip-drawer-open');
    if (this.drawerTarget.classList.contains("open")) {
      this.drawerTarget.classList.remove("open")
      this.drawerTarget.style.top = `${viewportHeight - 80}px`;
      var currentMode = "closed";
    } else {
      const topPosition = viewportHeight - drawerHeight - 40;
      this.drawerTarget.style.top = `${topPosition}px`;
      this.drawerTarget.className += " open"
      var currentMode = "open";
    }
    
  }


}