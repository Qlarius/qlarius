import { Controller } from "@hotwired/stimulus"

export default class extends Controller {

  static values = {
    traitid: String
  }

  
  flash_green() {
    let tagEl = document.getElementById('tag-box-trait-id-'+this.traitidValue)
    console.log(tagEl)
    for (var i = 0; i < tagEl.children.length; i++) {
      tagEl.children[i].classList.add('flash-green');
    }
    setTimeout(function(){
      console.log('remove class ' + this.traitidValue)
      for (var i = 0; i < tagEl.children.length; i++) {
        tagEl.children[i].classList.remove('flash-green');
      }
    },800);
  }

  flash_red() {
    let tagEl = document.getElementById('tag-box-trait-id-'+this.traitidValue)
    for (var i = 0; i < tagEl.children.length; i++) {
      tagEl.children[i].classList.add('flash-red')
    }
    tagEl.classList.add('delete-shrink')
  }

  delete_tag() {

  }
}
