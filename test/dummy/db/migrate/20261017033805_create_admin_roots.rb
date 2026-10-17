class CreateAdminRoots < ActiveRecord::Migration[8.1]
  def change
    create_table :admin_roots, id: :uuid do |t|
      t.string :name

      t.timestamps
    end
  end
end
