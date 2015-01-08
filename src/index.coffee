getter = (fn) -> 
  get: -> fn()
  enumerable: true

Object.defineProperties module.exports,
  Publisher: getter -> require "./publisher"
