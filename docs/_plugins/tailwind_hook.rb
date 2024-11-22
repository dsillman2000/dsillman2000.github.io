Jekyll::Hooks.register :site, :post_write do |site|
    # Build Tailwind CSS using the npm script
    system("npm run build:css")
  end