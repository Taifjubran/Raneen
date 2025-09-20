// Action Cable provides the framework to deal with WebSockets in Rails.
// You can generate new channels with the rails generate channel command.

(function() {
  this.App || (this.App = {});

  App.cable = ActionCable.createConsumer();

}).call(this);