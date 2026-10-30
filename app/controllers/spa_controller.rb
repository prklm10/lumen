# Serves the Vue app shell for every non-API HTML route; Vue Router takes it from there.
class SpaController < ApplicationController
  allow_unauthenticated_access

  def show
  end
end
