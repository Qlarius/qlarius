import { Controller } from "@hotwired/stimulus"
import { get } from '@rails/request.js'


// Connects to data-controller="app"
export default class extends Controller {

  static targets = [ "mobileNumber", "homeZip", "tagCount", "offerCount", 
                    "balance", "modal", "sidebar", "panelRight", "backdrop", 
                    "backdropStatic", "appPage", "bmLink", "login", "loader", "logoutButton", "logoutDialog" ]

  static values = {
    session: Boolean
  }

  connect() {
    this.update_mefile_stats()
    // this.set_session_status_listner()
    // this.toggleLogin()
  }

  loadNewPage() {
    console.log('new page loaded')
    this.toggleBottomMenu()
    this.hideLoader()
    window.scrollTo(0,0)
    this.update_mefile_stats()
  }

  showLoader() {
    console.log('showing loader')
    this.loaderTarget.style.display = ""
    this.loaderTarget.style.visibility = "visible"
  }

  hideLoader() {
    console.log('hiding loader')
    this.loaderTarget.style.display = "none"
    this.loaderTarget.style.visibility = "hidden"
  }

  // set_session_status_listner() {
  //   console.log('setting listener')
  //   const elementToObserve = window.document.getElementById('session-status-string')
  //   console.log('observing element ' + elementToObserve)
  //   const observer = new MutationObserver(() => {
  //     console.log('session-status-string changed')
  //     this.toggleLogin()
  //   });
  //   observer.observe(elementToObserve, {characterData: true, subtree: true});
  // }

  // sessionValueChanged() {
  //   console.log("sessionValue = " + this.sessionValue)
  //   this.toggleLogin()
  // }

  // toggleLogin() {
  //   console.log("toggle login")
  //   if (window.document.getElementById('session-status-string').innerText=="false") {
  //     this.openLogin()
  //   } else {
  //     this.closeLogin()
  //   }
  // }

  // openLogin() {
  //   console.log("open login")
  //   document.body.style.overflow = "hidden";
  //   this.loginTarget.style.display = "block"
  //   this.loginTarget.style.visibility = "visible"
  //   this.backdropStaticTarget.classList.remove("d-none")
  //   setTimeout( () => {
  //     this.loginTarget.classList.add("show")
  //     this.backdropStaticTarget.classList.add("show")
  //     this.backdropStaticTarget.classList.remove("d-none")
  //   }, 100)
  // }

  // closeLogin() {
  //   console.log("close login")
  //   this.loginTarget.classList.remove("show")
  //   this.loginTarget.style.display = "hidden"
  //   this.loginTarget.style.visibility = "hidden"
  //   document.body.removeAttribute("style")
  //   setTimeout( () => {
  //     this.loginTarget.style.display = "none"
  //     this.backdropStaticTarget.classList.remove("show")
  //   }, 400)
  //   setTimeout(() => {
  //     this.backdropStaticTarget.classList.add("d-none")
  //   }, 800)
  // }

  clearSession() {
    console.log('clearing session')
    localStorage.removeItem("psg_auth_token");
    localStorage.removeItem("psg_refresh_token");
    // localStorage.removeItem("psg_last_login");
    // window.document.getElementById("session-status-string").innerText = "false"
    // this.toggleLogin()
  }

  openModal() {
    document.body.style.overflow = "hidden";
    this.modalTarget.style.display = "block"
    this.backdropTarget.classList.remove("d-none")
    setTimeout( () => {
      this.modalTarget.classList.add("show")
      this.backdropTarget.classList.add("show")
    }, 100)
  }

  closeModal() {
    this.modalTarget.classList.remove("show")
    document.body.removeAttribute("style")
    setTimeout( () => {
      this.modalTarget.style.display = "none"
      this.backdropTarget.classList.remove("show")
    }, 400)
    setTimeout(() => {
      this.backdropTarget.classList.add("d-none")
    }, 800)
  }

  toggleBottomMenu() {
    const whichItem = this.appPageTarget.dataset.appPageAppPageValue
    this.bmLinkTargets.forEach(item => {
      item.classList.remove("active")  
      if (item.dataset.bottomMenuItem === whichItem) { item.classList.add("active") }
    });
  }

  openSidebar() {
    document.body.style.overflow = "hidden";
    this.sidebarTarget.style.visibility = "visible"
    this.backdropTarget.classList.remove("d-none")
    setTimeout( () => {
      this.sidebarTarget.classList.add("show")
      this.backdropTarget.classList.add("show")
    }, 100)
    
  }

  closeSidebar() {
    this.sidebarTarget.classList.remove("show")
    this.backdropTarget.classList.remove("show")
    document.body.removeAttribute("style")
    setTimeout( () => {
      this.backdropTarget.classList.add("d-none")
    }, 100)
  }

  openPanelRight() {
    document.body.style.overflow = "hidden";
    this.panelRightTarget.style.visibility = "visible"
    this.backdropTarget.classList.remove("d-none")
    setTimeout( () => {
      this.panelRightTarget.classList.add("show")
      this.backdropTarget.classList.add("show")
    }, 100)
    
  }

  closePanelRight() {
    this.panelRightTarget.classList.remove("show")
    this.backdropTarget.classList.remove("show")
    document.body.removeAttribute("style")
    setTimeout( () => {
      this.backdropTarget.classList.add("d-none")
    }, 100)
  }

  openLogoutDialog() {
    document.body.style.overflow = "hidden";
    this.logoutDialogTarget.style.display = "block"
    this.backdropTarget.classList.remove("d-none")
    setTimeout( () => {
      this.logoutDialogTarget.classList.add("show")
      this.backdropTarget.classList.add("show")
      this.backdropTarget.classList.remove("d-none")
    }, 100) 
  }

  closeLogoutDialog() {
    this.logoutDialogTarget.classList.remove("show")
    document.body.removeAttribute("style")
    setTimeout( () => {
      this.logoutDialogTarget.style.display = "none"
      this.backdropTarget.classList.remove("show")
    }, 400)
    setTimeout(() => {
      this.backdropTarget.classList.add("d-none")
    }, 800)
  }

  loadSelectedPage() {
    console.log('load selected page')
    this.showLoader()
    this.update_mefile_stats
  }

  async update_mefile_stats() {
    const response = await get('/api/v1/stats/user_stats', { responseKind: "json" })
    const json =  await response.json

    this.mobileNumberTargets.forEach(element => {
      element.innerHTML = json.user_alias
    });
    this.homeZipTargets.forEach(element => {
      element.innerHTML = json.home_zip
    });
    this.tagCountTargets.forEach(element => {
      if (json.response_code == "200" && json.trait_tag_count > 0) {
      element.innerHTML = json.trait_tag_count
      element.style.display = ""
      } else {
      element.style.display = "none"
      }
    });  
    this.offerCountTargets.forEach(element => {
      if (json.response_code == "200" && json.current_offer_count > 0) {
        element.innerHTML = json.current_offer_count
        element.style.display = ""
      } else {
        element.style.display = "none"
      }
    });
    const formatter = new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD',
    });
    this.balanceTargets.forEach(element => {
      if (json.response_code == "200" && json.ledger_balance > 0) {
        element.innerHTML = formatter.format(json.ledger_balance)
        element.style.display = ""
      } else {
      element.style.display = "none"
      }
    });
    if (json.response_code == "200") {
      this.logoutButtonTarget.style.display = ""
    } else {
      this.logoutButtonTarget.style.display = "none"
    }
  }

  hideStats() {
    console.log('hide stats')
    this.mobileNumberTargets.forEach(element => {
      element.innerHTML = ""
    });
    this.homeZipTargets.forEach(element => {
      element.innerHTML = ""
    });
    this.tagCountTargets.forEach(element => {
      element.style.display = "none"
    });  
    this.offerCountTargets.forEach(element => {
      element.style.display = "none"
    });
    this.balanceTargets.forEach(element => {
      element.style.display = "none"
    });
  }

}
